-- Terminal picker for neovim-agents plugin
--
-- Provides fuzzy finder UI for selecting agent terminals with:
-- - Telescope integration (preferred) with live preview of agent conversations
-- - vim.ui.select fallback for users without Telescope
-- - Rename capability directly from picker with <C-r>
-- - Automatic return to terminal insert mode after selection
-- - Agent type picker for multi-agent support
--
-- Features:
-- - Live preview showing terminal buffer content
-- - Status indicators (running/stopped, age)
-- - Fuzzy search by agent name
-- - Picker automatically reopens after rename for seamless workflow
-- - Agent selection UI for choosing which CLI to use
--
local tabs = require("neovim-agents.tabs")
local terminal = require("neovim-agents.terminal")

local M = {}

-- Format terminal info for display in picker
-- @param term Terminal metadata object
-- @return string Formatted display string
local function format_terminal_display(term)
  local status_icon = "?"  -- Running
  local status_text = "running"
  
  -- Check if terminal is actually running
  if not terminal.is_running(term.id) then
    status_icon = "?"  -- Stopped
    status_text = "stopped"
  end
  
  -- Calculate age
  local age_seconds = os.time() - term.created_at
  local age_str
  if age_seconds < 60 then
    age_str = age_seconds .. "s ago"
  elseif age_seconds < 3600 then
    age_str = math.floor(age_seconds / 60) .. "m ago"
  else
    age_str = math.floor(age_seconds / 3600) .. "h ago"
  end
  
  -- Get agent type (with fallback for backward compatibility)
  local agent_type = term.agent_type or "cursor"
  
  -- Format: "[cursor] Agent 1 (running, 5m ago)"
  return string.format("[%s] %s %s (%s, %s)", agent_type, status_icon, term.name, status_text, age_str)
end

-- Check if Telescope is available
local function has_telescope()
  return pcall(require, "telescope")
end

-- Pick terminal using Telescope (if available)
-- @param terminals Array of terminal metadata
-- @param config Configuration object
-- @param callback function(selected_id) Called with selected terminal ID
local function pick_with_telescope(terminals, config, callback)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    return false
  end
  
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  
  -- Build entries for telescope
  local entries = {}
  for _, term in ipairs(terminals) do
    table.insert(entries, {
      id = term.id,
      display = format_terminal_display(term),
      ordinal = term.name,  -- For searching/filtering
      value = term,
    })
  end

  -- Create a custom previewer for terminal buffers
  local terminal_previewer = previewers.new_buffer_previewer({
    title = "Agent Conversation",
    define_preview = function(self, entry, status)
      -- Get the terminal info
      local term_info = terminal._get_terminal(entry.id)

      if term_info and term_info.buf and vim.api.nvim_buf_is_valid(term_info.buf) then
        -- Get terminal buffer lines
        local lines = vim.api.nvim_buf_get_lines(term_info.buf, 0, -1, false)

        -- Set lines in preview buffer
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

        -- Optional: Set filetype for syntax highlighting
        vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'terminal')
      else
        -- Terminal not running or buffer invalid
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          "Terminal not running",
          "",
          "Status: " .. (terminal.is_running(entry.id) and "running" or "stopped")
        })
      end
    end,
  })

  pickers.new({}, {
    prompt_title = "Select Cursor Agent Terminal",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          display = entry.display,
          ordinal = entry.ordinal,
          id = entry.id,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = terminal_previewer,
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: select terminal
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          callback(selection.id)
          -- Enter insert mode in the terminal after switching
          vim.schedule(function()
            vim.cmd("startinsert")
          end)
        end
      end)
      
      -- Custom action: rename terminal with <C-r>
      map("i", "<C-r>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local term = selection.value
          actions.close(prompt_bufnr)
          
          -- Prompt for new name
          vim.schedule(function()
            vim.ui.input({
              prompt = "Rename agent window: ",
              default = term.name,
            }, function(input)
              if input and input ~= "" then
                if tabs.rename_terminal(selection.id, input) then
                  vim.notify("Terminal renamed to: " .. input, vim.log.levels.INFO)
                  -- Re-open picker to show updated names
                  vim.schedule(function()
                    M.pick_terminal(config, callback)
                  end)
                else
                  vim.notify("Failed to rename terminal", vim.log.levels.ERROR)
                end
              end
            end)
          end)
        end
      end)
      
      -- Also map <C-r> in normal mode for Telescope
      map("n", "<C-r>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local term = selection.value
          actions.close(prompt_bufnr)
          
          -- Prompt for new name
          vim.schedule(function()
            vim.ui.input({
              prompt = "Rename agent window: ",
              default = term.name,
            }, function(input)
              if input and input ~= "" then
                if tabs.rename_terminal(selection.id, input) then
                  vim.notify("Terminal renamed to: " .. input, vim.log.levels.INFO)
                  -- Re-open picker to show updated names
                  vim.schedule(function()
                    M.pick_terminal(config, callback)
                  end)
                else
                  vim.notify("Failed to rename terminal", vim.log.levels.ERROR)
                end
              end
            end)
          end)
        end
      end)
      
      return true
    end,
  }):find()
  
  return true
end

-- Pick terminal using vim.ui.select (fallback)
-- @param terminals Array of terminal metadata
-- @param callback function(selected_id) Called with selected terminal ID
local function pick_with_ui_select(terminals, callback)
  -- Build display items
  local items = {}
  local id_map = {}
  
  for i, term in ipairs(terminals) do
    items[i] = format_terminal_display(term)
    id_map[i] = term.id
  end
  
  vim.ui.select(items, {
    prompt = "Select Cursor Agent Terminal:",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if idx then
      callback(id_map[idx])
      -- Enter insert mode in the terminal after switching
      vim.schedule(function()
        vim.cmd("startinsert")
      end)
    end
  end)
end

-- Main picker function - shows terminal selection UI
-- @param config Configuration object
-- @param callback function(selected_id) Called with selected terminal ID
function M.pick_terminal(config, callback)
  local terminals = tabs.list_terminals()
  
  -- Handle edge cases
  if #terminals == 0 then
    vim.notify("No terminals available. Create one with <leader>an", vim.log.levels.WARN)
    return
  end
  
  if #terminals == 1 then
    -- Only one terminal, auto-select it (or show picker anyway based on config)
    -- For now, let's auto-select to avoid unnecessary UI
    callback(terminals[1].id)
    return
  end
  
  -- Try Telescope first, fall back to vim.ui.select
  if has_telescope() then
    local success = pick_with_telescope(terminals, config, callback)
    if success then
      return
    end
  end
  
  -- Fallback to vim.ui.select
  pick_with_ui_select(terminals, callback)
end

-- Pick agent using Telescope (if available)
-- @param agents Array of agent objects
-- @param config Configuration object
-- @param callback function(agent_type) Called with selected agent type
local function pick_agent_with_telescope(agents, config, callback)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    return false
  end
  
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  -- Build entries for telescope
  local entries = {}
  for _, agent in ipairs(agents) do
    local display = agent.type
    if agent.type == config.default_agent then
      display = agent.type .. " (default)"
    end
    
    table.insert(entries, {
      type = agent.type,
      command = agent.command,
      display = display,
      ordinal = agent.type,
    })
  end
  
  pickers.new({}, {
    prompt_title = "Select AI Agent",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.type,
          display = entry.display,
          ordinal = entry.ordinal,
          type = entry.type,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Default action: select agent
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          callback(selection.type)
        end
      end)
      
      return true
    end,
  }):find()
  
  return true
end

-- Pick agent using vim.ui.select (fallback)
-- @param agents Array of agent objects
-- @param callback function(agent_type) Called with selected agent type
local function pick_agent_with_ui_select(agents, callback)
  -- Build display items
  local items = {}
  local type_map = {}
  
  for i, agent in ipairs(agents) do
    items[i] = agent.type
    type_map[i] = agent.type
  end
  
  vim.ui.select(items, {
    prompt = "Select AI Agent:",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if idx then
      callback(type_map[idx])
    end
  end)
end

-- Agent picker function - shows agent selection UI
-- @param config Configuration object
-- @param callback function(agent_type) Called with selected agent type
function M.pick_agent(config, callback)
  -- Get list of configured agents
  local agents = {}
  for agent_type, agent_config in pairs(config.agents) do
    table.insert(agents, {
      type = agent_type,
      command = agent_config.command,
    })
  end
  
  -- Sort agents to ensure default is first
  table.sort(agents, function(a, b)
    if a.type == config.default_agent then
      return true
    elseif b.type == config.default_agent then
      return false
    else
      return a.type < b.type
    end
  end)
  
  -- Handle edge cases
  if #agents == 0 then
    vim.notify("No agents configured", vim.log.levels.ERROR)
    return
  end
  
  if #agents == 1 then
    -- Only one agent, auto-select it
    callback(agents[1].type)
    return
  end
  
  -- Try Telescope first, fall back to vim.ui.select
  if has_telescope() then
    local success = pick_agent_with_telescope(agents, config, callback)
    if success then
      return
    end
  end
  
  -- Fallback to vim.ui.select
  pick_agent_with_ui_select(agents, callback)
end

return M
