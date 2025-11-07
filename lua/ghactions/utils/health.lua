local M = {}

-- Check if plenary.nvim is available
local function has_plenary()
  local ok, plenary = pcall(require, "plenary")
  return ok and plenary
end

-- Check if telescope.nvim is available
local function has_telescope()
  local ok, telescope = pcall(require, "telescope")
  return ok and telescope
end

-- Check if GitHub CLI is available
local function has_gh_cli()
  local handle = io.popen "gh --version 2>/dev/null"
  if not handle then
    return false
  end

  local result = handle:read "*a"
  handle:close()

  return result and result:match "gh version" ~= nil
end

-- Check Neovim version
local function check_neovim_version()
  if not vim.version then
    return true -- Skip version check if vim.version not available
  end

  local version = vim.version()
  if version.major == 0 and version.minor < 7 then
    return false,
      string.format(
        "Neovim version %d.%d.%d is too old. Requires >= 0.7.0",
        version.major,
        version.minor,
        version.patch
      )
  end
  return true
end

-- Health check function
function M.check()
  local health_ok = true
  local issues = {}

  -- Check Neovim version
  local nvim_ok, nvim_msg = check_neovim_version()
  if not nvim_ok then
    health_ok = false
    table.insert(issues, nvim_msg)
  end

  -- Check plenary.nvim
  if not has_plenary() then
    health_ok = false
    table.insert(issues, "plenary.nvim is required but not found")
  end

  -- Check telescope.nvim
  if not has_telescope() then
    health_ok = false
    table.insert(issues, "telescope.nvim is required but not found")
  end

  -- Check GitHub CLI
  if not has_gh_cli() then
    health_ok = false
    table.insert(issues, "GitHub CLI (gh) is required but not found")
  end

  -- Report results
  if not health_ok then
    local msg = "ghactions.nvim: Dependency issues found:\n" .. table.concat(issues, "\n")
    vim.notify(msg, vim.log.levels.ERROR)
  end

  return health_ok
end

return M
