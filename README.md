# neovim-agents

**BIG DISCLAIMER**: This is not a _real_ plugin in the `neovim` sense of a plugin. It's just a way to integrate AI agent CLIs into the `neovim` editor. So whenever you read that it's a "plugin", just read it as "terminal integration" (or something like that).

A Neovim plugin to integrate AI agent CLIs (Cursor, Claude, Gemini, etc.) directly into your editor. Toggle terminals running your favorite AI agents with simple keybindings and send visual selections for AI assistance.

This was created using cursor 😊 in 20 minutes, it doesn't have to be perfect, just need something to run AI agents like the agent inside cursor.


## Features

- 🚀 Toggle a vertical split terminal running AI agent CLIs with `<leader>ai`
- 🤖 **Multi-agent support** - Use Cursor, Claude, Gemini, or any AI CLI
- 🎛️ **Manage multiple AI agent sessions simultaneously**
- 🔍 **Fuzzy finder with live preview** (Telescope integration)
- ✏️ **Rename and organize** agent terminals for different tasks
- ⌨️ **Full terminal mode support** - manage agents without leaving the terminal
- 📝 Send visual selections and file paths to AI agents
- 💾 Persistent terminal sessions (hide/show without restarting)
- ⚙️ Fully configurable (keybindings, split position, size, agents, etc.)
- 🎯 Written in pure Lua


## Requirements

- Neovim >= 0.8.0
- One or more AI agent CLIs installed and available in your PATH:
  - `cursor` CLI (Cursor AI)
  - `claude` CLI (Anthropic Claude)
  - `gemini` CLI (Google Gemini)
  - Or any other AI agent CLI


## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "felixcuello/neovim-agents",
  config = function()
    require("neovim-agents").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "felixcuello/neovim-agents",
  config = function()
    require("neovim-agents").setup()
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'felixcuello/neovim-agents'

lua << EOF
require("neovim-agents").setup()
EOF
```

## Usage

### Quick Start

1. **Open/Toggle Agent**: Press `<leader>ai` in normal mode
   - First time: Select an agent type (cursor/claude/gemini), then creates your first agent terminal
   - After that: Toggles (show/hide) the last active agent
2. **Create New Agent**: Press `<leader>an` to select agent type and create additional agent terminals
3. **Switch Agents**: Press `<leader>at` to open a fuzzy picker with live preview showing `[agent_type]`
4. **Rename Agent**: Press `<leader>ar` to rename the current agent terminal

### Multi-Terminal Management

Work with multiple AI agents simultaneously for different tasks:

#### From Normal Mode

| Keybinding | Action |
|------------|--------|
| `<leader>ai` | Smart toggle - create first agent or show last active |
| `<leader>an` | Create new agent terminal with custom prompt |
| `<leader>at` | Select agent from fuzzy picker (with live preview) |
| `<leader>ar` | Rename current agent terminal |

#### From Terminal Mode

When you're inside an agent terminal, you can manage agents without leaving:

| Keybinding | Action |
|------------|--------|
| `<Esc>` | Exit terminal mode / hide agent window |
| `<C-n>` | Create new agent terminal |
| `<C-t>` | Select agent from fuzzy picker |
| `<C-r>` | Rename current agent terminal |

#### Example Workflow

```
1. Press <leader>ai → Agent picker appears → Select "cursor"
2. Ask: "Help me debug this authentication issue"
3. Press <C-n> → Agent picker appears → Select "claude"
4. Type: "Review my database schema"
5. Now you have two agents running! (one cursor, one claude)
6. Press <C-t> → Telescope shows:
   - [cursor] Agent 1 (running, 5m ago)
   - [claude] Agent 2 (running, 2m ago)
7. Navigate and press Enter to switch
8. Press <C-r> → Rename to "Auth Debug" and "Schema Review"
```

### Visual Mode

Send code selections to your active agent:

1. Select text in visual mode (v, V, or Ctrl-v)
2. Press `<leader>ai`
3. The plugin will:
   - Toggle the agent terminal (show it)
   - Send the file path with line range (e.g., `@file.lua:10-20`)

Example:
```
@/path/to/your/file.lua:10-15
```

The agent will have context about which file and lines you're referring to.

### Commands

The plugin provides comprehensive commands for all operations:

#### Terminal Management
- `:CursorAgent` - Toggle agent terminal (smart toggle)
- `:CursorAgentNew [agent_type] [prompt]` - Create new agent terminal with optional agent type and prompt
  - Example: `:CursorAgentNew cursor My Project` - Create cursor agent named "My Project"
  - Example: `:CursorAgentNew claude` - Create claude agent with auto-generated name
  - Example: `:CursorAgentNew` - Show agent picker, then create with auto-generated name
- `:CursorAgentSelect` - Open agent picker
- `:CursorAgentRename [name]` - Rename active agent (interactive if no argument)
- `:CursorAgentList` - List all agent terminals with status and agent type

> **Note:** To close an agent terminal, simply type `exit` in the terminal or press `Ctrl+D`

#### Utilities
- `:CursorAgentSend <text>` - Send arbitrary text to active agent
- `:CursorAgentVersion` - Display plugin version

## Configuration

### Default Configuration

```lua
require("neovim-agents").setup({
  -- Multi-terminal keybindings (all configurable)
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
    position = "right",  -- "right", "left", "top", "bottom"
    size = 0.5,          -- 50% of editor width/height (0.0-1.0)
  },

  -- Multi-agent configuration
  agents = {
    cursor = { command = "cursor agent" },
    claude = { command = "claude" },
    gemini = { command = "gemini chat" },
  },

  -- Default agent (first in list if not specified)
  default_agent = "cursor",

  -- Terminal callbacks (optional)
  term_opts = {
    on_open = function()
      -- Called when terminal opens
      print("AI agent started")
    end,
    on_close = function(exit_code)
      -- Called when terminal closes
      print("AI agent exited with code: " .. exit_code)
    end,
  },
})
```

### Custom Configuration Examples

#### Configure Multiple AI Agents

```lua
require("neovim-agents").setup({
  agents = {
    cursor = { command = "cursor agent" },
    claude = { command = "claude --interactive" },
    gemini = { command = "gemini chat" },
    gpt = { command = "gpt-cli" },
  },
  default_agent = "cursor",  -- Used when no agent specified
})
```

#### Single Agent Setup (Backward Compatible)

```lua
require("neovim-agents").setup({
  command = "cursor agent",  -- Old style - still works!
})
-- This automatically creates a single "cursor" agent
```

#### Custom Keybindings

```lua
require("neovim-agents").setup({
  keybindings = {
    toggle = "<C-a>",       -- Use Ctrl+a for toggle
    new = "<C-n>",          -- Use Ctrl+n for new terminal
    select = "<C-s>",       -- Use Ctrl+s for select
    rename = "<leader>rn",  -- Use <leader>rn for rename
  },
})
```

#### Custom Terminal Names

```lua
require("neovim-agents").setup({
  terminal = {
    default_name = "AI Assistant",  -- Custom prefix
    auto_number = true,              -- "AI Assistant 1", "AI Assistant 2", etc.
  },
})
```

#### Left Split with 40% Width

```lua
require("neovim-agents").setup({
  split = {
    position = "left",
    size = 0.4,
  },
})
```

#### Custom Agent Commands with Arguments

```lua
require("neovim-agents").setup({
  agents = {
    cursor = { command = "cursor agent" },
    claude_sonnet = { command = "claude --model sonnet" },
    claude_opus = { command = "claude --model opus" },
    gpt4 = { command = "openai-cli --model gpt-4" },
  },
  default_agent = "cursor",
})
```

#### Backward Compatibility

The old `keybinding` and `command` options are still supported:

```lua
require("neovim-agents").setup({
  keybinding = "<leader>ai",  -- Still works, sets the toggle keybinding
  command = "cursor agent",   -- Still works, creates single cursor agent
})
```

## Multi-Agent Support

### Agent Selection Flow

When you create a new terminal (`<leader>an` or first time with `<leader>ai`):
1. A picker appears showing all configured agents
2. The default agent is pre-selected at the top
3. Select an agent (cursor, claude, gemini, etc.)
4. Terminal is created with that specific agent

### Agent Type Display

Agent types are displayed in square brackets throughout the UI:
- Terminal picker: `[cursor] Agent 1 (running, 5m ago)`
- Terminal list: `[claude] Debug Session [running] (created 2h ago)`
- Switching between agents clearly shows which CLI each terminal uses

### Per-Terminal Agent Types

Each terminal remembers its agent type:
- Create terminals with different agents
- Each terminal uses its configured CLI command
- Switch between terminals seamlessly
- Agent type persists across show/hide

## Advanced Usage

### Programmatic Access

You can access the terminal functions directly:

```lua
local cursor = require("neovim-agents")

-- Access plugin version
print("Version: " .. cursor.version)

-- Toggle terminal
cursor.normal_mode_handler()

-- Create new terminal programmatically
cursor.new_terminal_handler()

-- Send text to active terminal
cursor.terminal.send_text("@myfile.lua\nExplain this code")

-- Check if terminal is running
local terminal_id = cursor.tabs.get_active()
if cursor.terminal.is_running(terminal_id) then
  print("Terminal is running")
end

-- List all terminals
local terminals = cursor.tabs.list_terminals()
for _, term in ipairs(terminals) do
  print(string.format("%s: %s", term.id, term.name))
end

-- Get terminal state (for debugging)
local state = cursor.tabs.get_state()
print(vim.inspect(state))
```

### Multi-Terminal API

```lua
local tabs = require("neovim-agents.tabs")

-- Get active terminal ID
local active_id = tabs.get_active()

-- Get terminal metadata
local term = tabs.get_terminal(active_id)
print("Name: " .. term.name)
print("Created: " .. term.created_at)

-- Rename a terminal
tabs.rename_terminal(active_id, "New Name")

-- Delete a terminal
tabs.delete_terminal(active_id)

-- Check if any terminals exist
if tabs.has_terminals() then
  print("Terminals count: " .. tabs.count())
end
```

## Tips & Best Practices

### Organizing Your Agents

Use descriptive names and different agent types for different tasks:
- **"Backend API" [cursor]** - cursor agent for backend questions
- **"Frontend UI" [claude]** - claude for UI/UX implementation
- **"Debug Session" [cursor]** - cursor for troubleshooting
- **"Code Review" [gemini]** - gemini for reviewing pull requests
- **"Documentation" [claude]** - claude for writing docs

### Efficient Workflows

1. **Keep agents focused**: Create separate agents for different contexts instead of mixing topics in one
2. **Use different agent types**: Try cursor for code, claude for explanations, gemini for research
3. **Use terminal mode shortcuts**: Stay in terminal mode with `<C-n>`, `<C-t>`, `<C-r>` for faster navigation
4. **Leverage the preview**: Use `<C-t>` to preview conversations before switching
5. **Name early**: Rename agents as soon as you know their purpose with `<C-r>`

### Telescope Integration

For the best experience, install [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). The picker will:
- Show live preview of agent conversations
- Support fuzzy searching by agent name
- Allow renaming directly from the picker with `<C-r>`

Without Telescope, the plugin falls back to `vim.ui.select` (still functional, just less features).

## Troubleshooting

### Terminal doesn't open

- Ensure the AI agent CLI is installed and in your PATH
- Try running the command manually in your terminal to verify it works (e.g., `cursor agent`, `claude`)
- Check for errors with `:messages`
- Verify your agent configuration: `:lua print(vim.inspect(require('neovim-agents.config').defaults.agents))`

### Agent picker doesn't show my agents

- Check your setup configuration has the `agents` table defined
- Verify commands are correct: `:lua print(vim.inspect(require('neovim-agents').tabs.get_state()))`

### Keybinding doesn't work

- Make sure `<leader>` is set in your config (e.g., `vim.g.mapleader = " "`)
- Check for conflicting keybindings with `:verbose map <leader>ai`

### Visual selection not working

- Ensure you're pressing `<leader>ai` while still in visual mode
- The selection will be sent after the terminal opens/shows

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Projects

- [Cursor](https://cursor.sh/) - The AI-first code editor
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) - Terminal management for Neovim
- [vim-floaterm](https://github.com/voldikss/vim-floaterm) - Floating terminal plugin
