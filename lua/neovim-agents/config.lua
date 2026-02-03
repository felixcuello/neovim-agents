-- Default configuration for neovim-agents plugin
local M = {}

M.defaults = {
  -- Keybinding for toggling cursor agent (backward compatibility)
  keybinding = "<leader>ai",

  -- Multi-terminal keybindings
  keybindings = {
    toggle = "<leader>ai",      -- Toggle agent window (show last active)
    new = "<leader>an",          -- Create new agent terminal
    select = "<leader>at",       -- Select agent terminal (fuzzy picker)
    rename = "<leader>ar",       -- Rename current agent terminal
  },

  -- Terminal naming configuration
  terminal = {
    default_name = "Agent",      -- Default name prefix for terminals
    auto_number = true,          -- Auto-append numbers (Agent 1, Agent 2, etc.)
  },

  -- Terminal split configuration
  split = {
    position = "right",  -- right, left, top, bottom
    size = 0.5,          -- 50% of editor width/height
  },

  -- CLI command to run (backward compatibility - will be converted to agents table)
  command = "cursor agent",

  -- Multi-agent configuration
  agents = {
    cursor = { command = "cursor agent" },
    claude = { command = "claude" },
    gemini = { command = "gemini chat" },
  },

  -- Default agent type (used when creating new terminals)
  default_agent = "cursor",

  -- Terminal options
  term_opts = {
    on_open = nil,   -- Callback when terminal opens
    on_close = nil,  -- Callback when terminal closes
  },
}

-- Merge user config with defaults
-- Maintains backward compatibility with old 'keybinding' and 'command' options
function M.setup(user_config)
  user_config = user_config or {}
  
  -- Backward compatibility: if old 'keybinding' provided but not 'keybindings', migrate it
  if user_config.keybinding and not user_config.keybindings then
    user_config.keybindings = {
      toggle = user_config.keybinding,
    }
  end
  
  -- Backward compatibility: if old 'command' provided but not 'agents', migrate it
  if user_config.command and not user_config.agents then
    user_config.agents = {
      cursor = { command = user_config.command },
    }
    user_config.default_agent = "cursor"
  end
  
  local config = vim.tbl_deep_extend("force", M.defaults, user_config)
  
  -- Ensure default_agent is valid
  if config.default_agent and not config.agents[config.default_agent] then
    -- Default agent doesn't exist, use first available agent
    for agent_type, _ in pairs(config.agents) do
      config.default_agent = agent_type
      break
    end
  end
  
  -- If no default_agent set, use first available agent
  if not config.default_agent then
    for agent_type, _ in pairs(config.agents) do
      config.default_agent = agent_type
      break
    end
  end
  
  return config
end

return M

