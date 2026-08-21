-- Main module for neovim-agents plugin
--
-- This is the entry point for the plugin, providing:
-- - Plugin setup and configuration
-- - User-facing handlers for all operations (normal/visual mode, terminal operations)
-- - Keybinding and command registration
-- - Integration between config, terminal, tabs, and picker modules
--
-- Key handlers:
-- - normal_mode_handler(): Smart toggle (create first terminal or show last active)
-- - visual_mode_handler(): Show agent and send @filepath:start-end from visual selection
-- - new_terminal_handler(): Create new agent terminal with prompt
-- - select_terminal_handler(): Open fuzzy picker to select agent
-- - rename_terminal_handler(): Rename active agent
--
local config_module = require("neovim-agents.config")
local terminal = require("neovim-agents.terminal")
local tabs = require("neovim-agents.tabs")
local picker = require("neovim-agents.picker")

local M = {}
local config = {}

-- Plugin version (Semantic Versioning: MAJOR.MINOR.PATCH)
-- v1.0.0: Multi-terminal support with fuzzy picker, live preview, and full configurability
M.version = "1.1.0"

-- Normal mode handler: smart toggle (create first terminal or show last active)
function M.normal_mode_handler()
  -- Check if any terminals exist
  if not tabs.has_terminals() then
    -- No terminals exist, show agent picker then create the first one
    picker.pick_agent(config, function(agent_type)
      tabs.create_terminal(nil, config, agent_type)
    end)
  else
    -- Terminals exist, toggle the last active one
    local last_id = tabs.get_last()
    if last_id then
      terminal.toggle(config, last_id)
    else
      -- Fallback: show agent picker then create a new terminal
      picker.pick_agent(config, function(agent_type)
        tabs.create_terminal(nil, config, agent_type)
      end)
    end
  end
end

-- Handler for creating a new terminal
function M.new_terminal_handler()
  -- Show agent picker, then create terminal with selected agent
  picker.pick_agent(config, function(agent_type)
    tabs.create_terminal(nil, config, agent_type)
  end)
end

-- Handler for creating a new terminal from within terminal mode
-- Hides current terminal first, then creates a new one
function M.new_terminal_from_terminal_handler()
  -- Hide the current terminal
  terminal.hide()

  -- Schedule the new terminal creation to happen after hiding completes
  vim.schedule(function()
    M.new_terminal_handler()
  end)
end

-- Handler for selecting a terminal from picker
function M.select_terminal_handler()
  picker.pick_terminal(config, function(selected_id)
    if selected_id then
      tabs.switch_to(selected_id, config)
    end
  end)
end

-- Handler for renaming the active terminal
function M.rename_terminal_handler()
  local active_id = tabs.get_active()
  
  if not active_id then
    vim.notify("No active terminal to rename. Create one with <leader>an", vim.log.levels.WARN)
    return
  end
  
  local term = tabs.get_terminal(active_id)
  local current_name = term and term.name or ""
  
  -- Check if we're currently in a terminal buffer
  local current_buf = vim.api.nvim_get_current_buf()
  local is_terminal_buf = vim.bo[current_buf].buftype == "terminal"

  vim.ui.input({
    prompt = "Rename agent window: ",
    default = current_name,
  }, function(input)
    if input and input ~= "" then
      if tabs.rename_terminal(active_id, input) then
        vim.notify("Terminal renamed to: " .. input, vim.log.levels.INFO)
        -- If we were in a terminal buffer, go back to insert mode
        if is_terminal_buf then
          vim.schedule(function()
            vim.cmd("startinsert")
          end)
        end
      else
        vim.notify("Failed to rename terminal", vim.log.levels.ERROR)
      end
    elseif is_terminal_buf then
      -- User cancelled, but if we were in terminal, go back to insert mode
      vim.schedule(function()
        vim.cmd("startinsert")
      end)
    end
  end)
end

-- Handler for listing all terminals
function M.list_terminals_handler()
  local terminals = tabs.list_terminals()
  
  if #terminals == 0 then
    vim.notify("No terminals available. Create one with <leader>an", vim.log.levels.INFO)
    return
  end
  
  local active_id = tabs.get_active()
  local lines = {"AI Agent Terminals:", ""}
  
  for i, term in ipairs(terminals) do
    local status = terminal.is_running(term.id) and "running" or "stopped"
    local active_marker = (term.id == active_id) and "? " or "  "
    local age_seconds = os.time() - term.created_at
    local age_str
    
    if age_seconds < 60 then
      age_str = age_seconds .. "s"
    elseif age_seconds < 3600 then
      age_str = math.floor(age_seconds / 60) .. "m"
    else
      age_str = math.floor(age_seconds / 3600) .. "h"
    end
    
    local agent_type = term.agent_type or "cursor"
    
    table.insert(lines, string.format("%s%d. [%s] %s [%s] (created %s ago)", 
      active_marker, i, agent_type, term.name, status, age_str))
  end
  
  table.insert(lines, "")
  table.insert(lines, string.format("Total: %d terminal(s)", #terminals))
  
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Retry sending text until the agent CLI is ready (or give up after ~1s)
local SEND_RETRY_ATTEMPTS = 20
local SEND_RETRY_MS = 50

local function send_when_ready(text, id, attempt)
  attempt = attempt or 0
  if id and terminal.is_running(id) then
    terminal.send_text(text, id)
    return
  end
  if attempt >= SEND_RETRY_ATTEMPTS then
    vim.notify("AI agent terminal is not running", vim.log.levels.WARN)
    return
  end
  vim.defer_fn(function()
    send_when_ready(text, id, attempt + 1)
  end, SEND_RETRY_MS)
end

-- Visual mode handler: show terminal and send @filepath:start-end
-- Must be called while still in visual mode so line("v") / line(".") are valid.
function M.visual_mode_handler()
  local filepath = vim.api.nvim_buf_get_name(0)
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "x", false)

  vim.schedule(function()
    local text_to_send = nil
    if filepath == "" then
      vim.notify("Cannot send selection: buffer has no file name", vim.log.levels.WARN)
    else
      text_to_send = "@" .. filepath .. ":" .. start_line .. "-" .. end_line
    end

    local function send_if_needed(id)
      if text_to_send then
        send_when_ready(text_to_send, id)
      end
    end

    if not tabs.has_terminals() then
      picker.pick_agent(config, function(agent_type)
        local id = tabs.create_terminal(nil, config, agent_type)
        send_if_needed(id)
      end)
    else
      local last_id = tabs.get_last()
      if last_id then
        local term_meta = tabs.get_terminal(last_id)
        terminal.ensure_visible(config, last_id, term_meta and term_meta.agent_type)
      end
      send_if_needed(last_id or tabs.get_active())
    end
  end)
end

-- Setup function to initialize the plugin
function M.setup(user_config)
  -- Merge user config with defaults
  config = config_module.setup(user_config)

  -- Support backward compatibility: if keybindings table not provided, use old keybinding
  local keybindings = config.keybindings or {
    toggle = config.keybinding or "<C-_>",
    new = "<leader>an",
    select = "<leader>at",
    rename = "<leader>ar",
  }

  -- Set up keybindings for toggle
  vim.keymap.set("n", keybindings.toggle, M.normal_mode_handler, {
    desc = "Toggle AI Agent terminal",
    silent = true,
  })

  vim.keymap.set("v", keybindings.toggle, M.visual_mode_handler, {
    desc = "Toggle AI Agent terminal and send selection",
    silent = true,
  })

  -- Keybinding for creating a new terminal
  vim.keymap.set("n", keybindings.new, M.new_terminal_handler, {
    desc = "Create new AI Agent terminal",
    silent = true,
  })

  -- Keybinding for selecting a terminal
  vim.keymap.set("n", keybindings.select, M.select_terminal_handler, {
    desc = "Select AI Agent terminal",
    silent = true,
  })

  -- Keybinding for renaming a terminal
  vim.keymap.set("n", keybindings.rename, M.rename_terminal_handler, {
    desc = "Rename AI Agent terminal",
    silent = true,
  })

  -- Create user command for toggle
  vim.api.nvim_create_user_command("CursorAgent", function()
    M.normal_mode_handler()
  end, {
    desc = "Toggle AI Agent terminal",
  })

  -- Create command to create new terminal
  vim.api.nvim_create_user_command("CursorAgentNew", function(opts)
    local args = vim.split(opts.args or "", "%s+")
    local agent_type = nil
    local name = nil
    
    -- Check if first arg is an agent type
    if #args > 0 and config.agents[args[1]] then
      agent_type = args[1]
      name = table.concat(vim.list_slice(args, 2), " ")
      if name == "" then name = nil end
    else
      name = opts.args and opts.args ~= "" and opts.args or nil
    end
    
    if agent_type then
      -- Agent type specified, create directly
      tabs.create_terminal(name, config, agent_type)
    else
      -- No agent type, show picker
      picker.pick_agent(config, function(selected_agent_type)
        tabs.create_terminal(name, config, selected_agent_type)
      end)
    end
  end, {
    desc = "Create new AI Agent terminal",
    nargs = "?",
  })

  -- Create command to select terminal
  vim.api.nvim_create_user_command("CursorAgentSelect", function()
    M.select_terminal_handler()
  end, {
    desc = "Select AI Agent terminal",
  })

  -- Create command to rename terminal
  vim.api.nvim_create_user_command("CursorAgentRename", function(opts)
    local active_id = tabs.get_active()
    if not active_id then
      vim.notify("No active terminal to rename", vim.log.levels.WARN)
      return
    end
    
    if opts.args and opts.args ~= "" then
      -- Name provided as argument
      if tabs.rename_terminal(active_id, opts.args) then
        vim.notify("Terminal renamed to: " .. opts.args, vim.log.levels.INFO)
      end
    else
      -- No argument, use the interactive handler
      M.rename_terminal_handler()
    end
  end, {
    desc = "Rename AI Agent terminal",
    nargs = "?",
  })

  -- Create command to list terminals
  vim.api.nvim_create_user_command("CursorAgentList", function()
    M.list_terminals_handler()
  end, {
    desc = "List all AI Agent terminals",
  })

  -- Create command to send text manually
  vim.api.nvim_create_user_command("CursorAgentSend", function(opts)
    local active_id = tabs.get_active()
    if active_id and terminal.is_running(active_id) then
      terminal.send_text(opts.args, active_id)
    else
      vim.notify("AI agent terminal is not running", vim.log.levels.WARN)
    end
  end, {
    desc = "Send text to AI Agent terminal",
    nargs = "+",
  })

  -- Create command to display version
  vim.api.nvim_create_user_command("CursorAgentVersion", function()
    vim.notify("neovim-agents v" .. M.version, vim.log.levels.INFO)
  end, {
    desc = "Display neovim-agents plugin version",
  })
end

-- Expose modules for advanced usage
M.terminal = terminal
M.tabs = tabs
M.picker = picker

return M

