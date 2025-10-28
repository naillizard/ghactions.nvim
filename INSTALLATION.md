# Installation Guide for Local Development

## Quick Setup

1. **Copy the plugin spec** to your LazyVim config:

```bash
cp /home/braz/Personal/ghactions.nvim/lazy_plugin_spec.lua ~/.config/nvim/lua/plugins/ghactions.lua
```

2. **Restart Neovim** completely

3. **Test basic functionality**:

```vim
:GhActionsCacheStats
:GhActions
:GhActionsVersions actions/checkout
```

## ✅ **Fixed Issues**

- **Syntax Error**: Fixed missing `end` statement in `versions.lua`
- **Plenary API**: Updated to use correct `plenary.scandir` instead of deprecated `ls()` method
- **Path Handling**: Fixed all path operations to work with plenary.path correctly
- **Cache Functions**: All cache operations now work properly

## Manual Plugin Spec

If you prefer to create the file manually, add this to `~/.config/nvim/lua/plugins/ghactions.lua`:

```lua
return {
  dir = vim.fn.expand("~/Personal/ghactions.nvim"),
  name = "ghactions",
  dev = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("ghactions").setup({
      cache = {
        ttl = 300, -- 5 minutes for testing
        max_size = 100,
      },
      github = {
        api_timeout = 5000,
        max_retries = 2,
      },
    })
  end,
  cmd = { 
    "GhActions", 
    "GhActionsVersions", 
    "GhActionsSecure", 
    "GhActionsUnsecure",
    "GhActionsSecureAll",
    "GhActionsUnsecureAll",
    "GhActionsCacheStats",
    "GhActionsCachePurge"
  },
  keys = {
    { "<leader>ga", "<cmd>GhActions<cr>", desc = "GitHub Actions", ft = "yaml" },
    { "<leader>gv", "<cmd>GhActionsVersions<cr>", desc = "Action Versions", ft = "yaml" },
  },
}
```

## Testing Commands

After installation, try these commands:

1. **Check plugin status**: `:GhActionsCacheStats`
2. **Show command menu**: `:GhActions`
3. **Browse action versions**: `:GhActionsVersions actions/checkout`
4. **Test securing**: Open a YAML file with `uses: actions/checkout@v3` and run `:GhActionsSecure`

## Troubleshooting

If you encounter issues:

1. **Check Lazy status**: `:Lazy log ghactions`
2. **Reload plugin**: `:Lazy reload ghactions`
3. **Restart Neovim** completely
4. **Verify path**: `:lua print(vim.fn.expand("~/Personal/ghactions.nvim"))`

## Development Workflow

For hot reloading during development:

```vim
:lua package.loaded['ghactions'] = nil
:lua require('ghactions').setup()
```

The plugin should now work correctly with your LazyVim setup!