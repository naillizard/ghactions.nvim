# Quick Start Guide: GitHub Actions Plugin

**Created**: 2025-10-23  
**Purpose**: Get started quickly with the GitHub Actions plugin

## Prerequisites

1. **Neovim 0.7.0+** - Required for plugin functionality
2. **GitHub CLI (`gh`)** - For GitHub API authentication
3. **Telescope.nvim** - For the picker interface

### Install GitHub CLI

```bash
# macOS
brew install gh

# Ubuntu/Debian
sudo apt install gh

# Windows
winget install GitHub.cli
```

### Authenticate GitHub CLI

```bash
gh auth login
# Follow the prompts to authenticate
```

## Installation

### Using Packer.nvim

```lua
use {
  'your-username/ghactions.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('ghactions').setup()
  end
}
```

### Using Vim-plug

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'your-username/ghactions.nvim'
```

### Using Lazy.nvim

```lua
{
  'your-username/ghactions.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim'
  },
  config = function()
    require('ghactions').setup()
  end
}
```

## Basic Configuration

```lua
require('ghactions').setup({
  -- GitHub API settings
  github_token = os.getenv('GITHUB_TOKEN'), -- Optional, uses gh CLI auth
  
  -- Cache settings
  cache_ttl = 3600, -- 1 hour
  cache_dir = vim.fn.stdpath('cache') .. '/ghactions',
  
  -- Telescope settings
  telescope_theme = 'ivy',
  
  -- File patterns
  workflow_patterns = {
    '.github/workflows/*.yml',
    '.github/workflows/*.yaml'
  }
})
```

## Usage

### Open Version Picker

1. Open a GitHub Actions workflow file (`.github/workflows/*.yml` or `*.yaml`)
2. Run the command:

```vim
:GhActionsVersions
```

Or use the keybinding (if configured):

```vim
<leader>ga
```

3. Navigate through actions using Telescope
4. Preview README content on the right
5. Press Enter to select a version

### Secure All Actions

```vim
:GhActionsSecureAll
```

This converts every action tag to its corresponding commit SHA while recording the original version in trailing comments.

### Unsecure All Actions

```vim
:GhActionsUnsecureAll
```

This restores secured actions back to their original tagged versions using the stored comments.

### Clear Cache

```vim
:GhActionsCachePurge
```

Clear all cached data and force fresh API calls.

## Workflow Example

### Before (using tags)

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - uses: actions/cache@v3
```

### After (pinned to SHAs)

```yaml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3df4ab1eba0f5869a5f0af5151b6c7226520e5e2
      - uses: actions/setup-node@64ed1c7eab4cce9714b9f7d0f6b9f9a8a5b88827
        with:
          node-version: '18'
      - uses: actions/cache@88522df9b8b9b6415c12df8133f09f40dcd442ea
```

## Key Features

### 🚀 Fast Performance
- Cache-first approach (90% hit rate)
- <200ms picker response time
- <100ms preview updates

### 🔍 Interactive Selection
- Telescope picker interface
- Real-time README preview
- Fuzzy search support

### 💾 Smart Caching
- Local cache with TTL
- Offline capability
- Automatic cache refresh

### 🔄 Version Management
- Pin tags to commit SHAs
- Unpin SHAs back to tags
- Batch operations support

## Common Workflows

### Update Single Action

1. Place cursor on action line
2. Run `:GhActionsVersions`
3. Select new version
4. Press Enter to update

### Review Action Changes

1. Open picker with `:GhActionsVersions`
2. Navigate between versions
3. Read release notes in preview
4. Make informed decision

### Ensure Reproducible Builds

1. Run `:GhActionsSecureAll` before committing
2. All actions secured to specific SHAs with recorded tags
3. Guaranteed reproducible workflows

## Troubleshooting

### "GitHub token not configured"

**Solution**: Install and authenticate GitHub CLI:
```bash
gh auth login
```

### "Not a workflow file"

**Solution**: Open a file in `.github/workflows/` with `.yml` or `.yaml` extension.

### "API rate limit exceeded"

**Solution**: Wait for rate limit reset or authenticate with GitHub CLI for higher limits.

### "Cache access denied"

**Solution**: Check cache directory permissions:
```bash
ls -la ~/.cache/nvim/ghactions
```

## Advanced Configuration

### Custom Keybindings

```lua
vim.api.nvim_set_keymap('n', '<leader>ga', '<cmd>GhActionsVersions<cr>', 
  { noremap = true, silent = true, desc = 'GitHub Actions' })
vim.api.nvim_set_keymap('n', '<leader>gs', '<cmd>GhActionsSecure<cr>', 
  { noremap = true, silent = true, desc = 'Secure Action' })
vim.api.nvim_set_keymap('n', '<leader>gu', '<cmd>GhActionsUnsecure<cr>', 
  { noremap = true, silent = true, desc = 'Unsecure Action' })
vim.api.nvim_set_keymap('n', '<leader>gS', '<cmd>GhActionsSecureAll<cr>', 
  { noremap = true, silent = true, desc = 'Secure All Actions' })
vim.api.nvim_set_keymap('n', '<leader>gU', '<cmd>GhActionsUnsecureAll<cr>', 
  { noremap = true, silent = true, desc = 'Unsecure All Actions' })
```

### Telescope Extension

```lua
-- Load the extension
require('telescope').load_extension('ghactions')

-- Use directly
:Telescope ghactions actions
```

### Custom Cache Settings

```lua
require('ghactions').setup({
  cache_ttl = 7200, -- 2 hours
  max_cache_size = 100 * 1024 * 1024, -- 100MB
  cache_cleanup_interval = 3600 -- 1 hour
})
```

## Performance Tips

1. **Use Cache**: Let the cache build up for faster responses
2. **Batch Operations**: Pin/unpin all actions at once
3. **Network**: Good internet connection for initial cache building
4. **Storage**: Ensure sufficient disk space for cache

## Next Steps

- Read the [full documentation](doc/ghactions.txt)
- Check out the [configuration options](lua/ghactions/config.lua)
- Review the [API reference](contracts/api.yaml)
- Contribute on [GitHub](https://github.com/your-username/ghactions.nvim)

## Support

- 🐛 Report issues: [GitHub Issues](https://github.com/your-username/ghactions.nvim/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-username/ghactions.nvim/discussions)
- 📖 Documentation: `:help ghactions`