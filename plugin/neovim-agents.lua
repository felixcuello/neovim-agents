-- Plugin entry point for neovim-agents
-- This file is automatically loaded by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_neovim_agents then
  return
end
vim.g.loaded_neovim_agents = true

-- Setup the plugin with default configuration
-- Users can override this by calling require('neovim-agents').setup() in their config
require("neovim-agents").setup()

