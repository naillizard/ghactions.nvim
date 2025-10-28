return {
  dir = vim.fn.expand "~/Personal/ghactions.nvim",
  name = "ghactions",
  dev = true,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("ghactions").setup {
      cache = {
        ttl = 300, -- 5 minutes for testing
        max_size = 100,
      },
      github = {
        api_timeout = 5000,
        max_retries = 2,
      },
      keys = {
        { "<leader>ga", "<cmd>GhActions<cr>", desc = "GitHub Actions" },
        { "<leader>gv", "<cmd>GhActionsVersions<cr>", desc = "Action Versions" },
      },
    }
  end,
  cmd = {
    "GhActions",
    "GhActionsVersions",
    "GhActionsSecure",
    "GhActionsUnsecure",
    "GhActionsSecureAll",
    "GhActionsUnsecureAll",
    "GhActionsCacheStats",
    "GhActionsCachePurge",
  },
}
