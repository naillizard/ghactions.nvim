# GhActions.nvim

GitHub Actions version management plugin for Neovim with Telescope integration and smart caching.

## Features

- Interactive GitHub Actions version selection with Telescope
- Smart caching for improved performance
- Pin actions to specific SHAs for security
- Workflow discovery and management
- Release information display

## Requirements

- Neovim >= 0.7.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [GitHub CLI](https://cli.github.com/) (gh)

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'yourusername/ghactions.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('ghactions').setup()
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'yourusername/ghactions.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('ghactions').setup({
      keys = {
        { "<leader>ga", "<cmd>GhActionsVersions<cr>", desc = "Browse workflow actions" },
        { "<leader>gs", "<cmd>GhActionsSecure<cr>", desc = "Secure action under cursor" },
        { "<leader>gS", "<cmd>GhActionsSecureAll<cr>", desc = "Secure all actions in file" },
        { "<leader>gu", "<cmd>GhActionsUnsecure<cr>", desc = "Restore tagged version" },
        { "<leader>gU", "<cmd>GhActionsUnsecureAll<cr>", desc = "Restore all actions" },
      },
    })
  end
}
```

> **Note:** The `keys` option in the plugin's `setup()` function is for the plugin's internal keymap management (with YAML/YML scoping). Do not confuse this with lazy.nvim's top-level `keys` option, which is for lazy loading. Use the plugin's `keys` configuration to get automatic filetype scoping and consistent keymap behavior.

## Usage

### Interactive Version Selection

```vim
:GhActionsVersions
```

Opens a Telescope picker to browse and select GitHub Actions versions.

**Key Features:**

- **Live Updates**: Press `Ctrl+U` to update to the latest version - the picker stays open and refreshes to show the new status
- **Version Preview**: View detailed information about each version including release notes and commit details
- **Smart Navigation**: Use Tab/Shift+Tab to move between results and preview, arrow keys to navigate
- **Smart Status**: See current version, latest version, and update status for each action
- **Consistent Logic**: Releases use commit SHAs for reproducibility, tags use tag names for readability
- **Reusable Workflow Support**: Works with `uses: owner/repo/.github/workflows/...@ref`, including private repositories via authenticated `gh`

### Secure Actions

```vim
:GhActionsSecure
```

Secure the current action by pinning it to a specific commit SHA.

### Secure All Actions

```vim
:GhActionsSecureAll
```

Secure every action in the current buffer. Each action is pinned to the commit SHA for its existing version (no automatic upgrades). A trailing `# <version>` comment is added so that the original tag can be restored later.

### Unsecure Actions

```vim
:GhActionsUnsecure
```

Revert the current action to its tagged version (using the trailing `# <version>` comment when available).

### Unsecure All Actions

```vim
:GhActionsUnsecureAll
```

Revert every secured action in the buffer back to its tagged version using the original version comments created during the secure step.

### Cache Management

```vim
:GhActionsCachePurge
```

Clear the local cache.

## Configuration

```lua
require('ghactions').setup({
  -- Cache configuration
  cache = {
    ttl = 3600, -- 1 hour in seconds
    max_size = 1000, -- Maximum number of cached items
  },
  
  -- GitHub configuration
  github = {
    api_timeout = 10000, -- 10 seconds
    max_retries = 3,
  },
  
  -- Telescope configuration
  telescope = {
    layout_strategy = 'horizontal',
    layout_config = {
      horizontal = {
        preview_width = 0.6, -- Preview takes 60% of width
        results_width = 0.4, -- List takes 40% of width
      },
    },
  },

  keys = {
    { "<leader>ga", "<cmd>GhActionsVersions<cr>", desc = "Browse workflow actions" },
    { "<leader>gs", "<cmd>GhActionsSecure<cr>", desc = "Secure action under cursor" },
    { "<leader>gS", "<cmd>GhActionsSecureAll<cr>", desc = "Secure all actions in file" },
    { "<leader>gu", "<cmd>GhActionsUnsecure<cr>", desc = "Restore tagged version" },
    { "<leader>gU", "<cmd>GhActionsUnsecureAll<cr>", desc = "Restore all actions" },
  },
})
```

> **Tip:** `ghactions.nvim` scopes configured keymaps to YAML/YML buffers by default. To target additional filetypes (or make them global), set `keys = { filetypes = { "yaml", "yml", "yaml.gha" }, mappings = { ... } }` or set `ft = false` on an individual mapping. Lazy.nvim (and other plugin managers) will still lazy-load the plugin the first time one of these keys is used, so you can keep `event = "VeryLazy"` (or similar) without duplicating filetype lists.

> **Important:** Use the plugin's `keys` configuration (inside `setup()`) for automatic filetype scoping and consistent behavior. Do not confuse this with lazy.nvim's top-level `keys` option, which is only for lazy loading.

## Version Selection Behavior

The plugin automatically chooses the appropriate version format based on the version type:

- **Release versions** → Use **commit SHA** for maximum reproducibility
- **Tag versions** → Use **tag name** for better readability

**Examples:**

- Selecting release `v4.0.0` → Updates to `actions/checkout@abc123def456`
- Selecting tag `v4.1.0` → Updates to `actions/checkout@v4.1.0`

**Command behavior:**

- `:GhActionsVersions` (Enter/Ctrl+U) → Uses type-based logic
- `:GhActionsSecure` → Uses type-based logic (release→SHA, tag→tag name)
- `:GhActionsUnsecure` → Uses stored tag comment when available, falling back to latest tag
- `:GhActionsSecureAll` / `:GhActionsUnsecureAll` → Apply security workflow across entire buffer

## Key Mappings

### In Action Picker (`:GhActionsVersions`)

- **Enter** - Select version and update action
- **Ctrl+U** - Quick update to latest version (picker stays open and refreshes)
- **q** - Close picker
- **Esc** - Close picker

### Navigation

- **Tab/Shift+Tab** - Navigate between results and preview
- **Ctrl+C** - Cancel and close picker
- **Arrow Keys** - Navigate through results
- **Enter** - Select item or view details
- **Ctrl+B (or b in normal mode)** - Go back to actions list (when viewing versions for an action)

**Navigation Flow:**

1. `:GhActionsVersions` shows actions in current file
   - **Duplicate actions are consolidated** into a single entry with concatenated line numbers (e.g., "Lines 14,23,31")
   - **Single actions** show individual line numbers (e.g., "Line 14")
2. Press **Enter** on an action to see available versions
3. Press **Ctrl+B** to go back to actions list (single press, with double-press protection)
4. Press **Ctrl+U** in the actions list to update to the latest version
   - **Consolidated actions**: Updates all occurrences with the selected version
   - **Single actions**: Updates only that specific occurrence

## License

MIT

