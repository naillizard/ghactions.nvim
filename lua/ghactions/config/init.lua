local M = {}

-- Default configuration
local default_config = {
  cache = {
    ttl = 3600, -- 1 hour in seconds
    max_size = 1000, -- Maximum number of cached items
  },
  github = {
    api_timeout = 10000, -- 10 seconds
    max_retries = 3,
  },
  telescope = {
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        preview_width = 0.6, -- Preview takes 60% of width
        results_width = 0.4, -- List takes 40% of width
      },
    },
  },
  keys = {
    filetypes = { "yaml", "yml" },
    mappings = {},
  },
}

-- Internal configuration state
local config = {}

-- Setup configuration
function M.setup(opts)
  opts = opts or {}

  if opts.keys and vim.tbl_islist(opts.keys) then
    opts = vim.deepcopy(opts)
    opts.keys = {
      mappings = opts.keys,
    }
  elseif opts.keys and opts.keys.mappings and vim.tbl_islist(opts.keys.mappings) then
    opts = vim.deepcopy(opts)
    opts.keys.mappings = opts.keys.mappings
  end

  config = vim.tbl_deep_extend("force", default_config, opts)
end

-- Get configuration value
function M.get(key)
  if not key then
    return config
  end

  local keys = {}
  for k in string.gmatch(key, "[^.]+") do
    table.insert(keys, k)
  end

  local value = config
  for _, k in ipairs(keys) do
    value = value[k]
    if value == nil then
      return nil
    end
  end

  return value
end

-- Get all configuration
function M.get_all()
  return vim.deepcopy(config)
end

return M
