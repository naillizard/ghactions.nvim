local M = {}

-- Module dependencies
local config = require "ghactions.config"
local health = require "ghactions.utils.health"

local commands_created = false

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

-- Initialize default configuration immediately so commands can be created early
config.setup(default_config)

local function tbl_isempty(tbl)
  return not tbl or next(tbl) == nil
end

local function normalize_keys_config()
  local keys_config = config.get "keys"
  if not keys_config then
    return nil
  end

  local mappings
  local default_filetypes

  if vim.tbl_islist(keys_config) then
    mappings = keys_config
    default_filetypes = { "yaml", "yml" }
  else
    mappings = keys_config.mappings or {}
    if keys_config.filetypes == false then
      default_filetypes = nil
    else
      default_filetypes = keys_config.filetypes or { "yaml", "yml" }
    end
  end

  if not mappings or tbl_isempty(mappings) then
    return nil
  end

  return {
    mappings = mappings,
    default_filetypes = default_filetypes,
  }
end

local function apply_keymap(mapping, buf)
  local lhs = mapping[1]
  local rhs = mapping[2]
  if not lhs or not rhs then
    return
  end

  local modes = mapping.mode or "n"
  local opts = {
    desc = mapping.desc,
    silent = mapping.silent ~= false,
    noremap = mapping.noremap ~= false,
  }

  if mapping.expr ~= nil then
    opts.expr = mapping.expr
  end

  if mapping.nowait ~= nil then
    opts.nowait = mapping.nowait
  end

  if buf then
    opts.buffer = buf
  end

  vim.keymap.set(modes, lhs, rhs, opts)
end

local function setup_keymaps()
  local key_config = normalize_keys_config()
  if not key_config then
    return
  end

  local global_mappings = {}
  local ft_lookup = {}

  for _, mapping in ipairs(key_config.mappings) do
    local filetypes = mapping.ft

    if filetypes == false then
      filetypes = nil
    elseif not filetypes or (type(filetypes) == "table" and tbl_isempty(filetypes)) then
      filetypes = key_config.default_filetypes
    end

    if type(filetypes) == "string" then
      filetypes = { filetypes }
    end

    if type(filetypes) == "table" then
      for _, ft in ipairs(filetypes) do
        if ft and ft ~= "" then
          ft_lookup[ft] = ft_lookup[ft] or {}
          table.insert(ft_lookup[ft], mapping)
        end
      end
    else
      table.insert(global_mappings, mapping)
    end
  end

  for _, mapping in ipairs(global_mappings) do
    apply_keymap(mapping)
  end

  if tbl_isempty(ft_lookup) then
    return
  end

  local group = vim.api.nvim_create_augroup("GhActionsKeymaps", { clear = true })

  for ft, mappings_for_ft in pairs(ft_lookup) do
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = ft,
      callback = function(event)
        for _, mapping in ipairs(mappings_for_ft) do
          apply_keymap(mapping, event.buf)
        end
      end,
    })
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.api.nvim_buf_get_option(buf, "filetype")
      local buf_mappings = ft_lookup[ft]
      if buf_mappings then
        for _, mapping in ipairs(buf_mappings) do
          apply_keymap(mapping, buf)
        end
      end
    end
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}
  config.setup(vim.tbl_deep_extend("force", default_config, opts))

  -- Check health
  health.check()

  -- Create user commands first (before loading extension)
  M._create_commands()

  -- Setup configured keymaps (with default YAML scoping)
  setup_keymaps()

  -- Load Telescope extension
  local ok, err = pcall(function()
    require "ghactions.telescope.extension"
  end)

  if not ok then
    vim.notify("Failed to load Telescope extension: " .. err, vim.log.levels.WARN)
  end
end

-- Create user commands
function M._create_commands()
  if commands_created then
    return
  end

  local function require_or_notify(module_name)
    local ok, module = pcall(require, module_name)
    if not ok then
      vim.notify("ghactions.nvim failed to load " .. module_name .. ": " .. module, vim.log.levels.ERROR)
      return nil
    end
    return module
  end

  -- GhActionsVersions - Show actions in current file with update status
  vim.api.nvim_create_user_command("GhActionsVersions", function(opts)
    local pickers = require_or_notify "ghactions.telescope.pickers"
    if not pickers then
      return
    end

    local action_name = opts.args and opts.args ~= "" and opts.args or nil
    
    if action_name then
      -- If action name is provided, show versions for that specific action
      pickers.pick_versions {
        action_name = action_name,
        on_select = function(version_entry)
          vim.notify("Selected version: " .. version_entry.version, vim.log.levels.INFO)
        end,
      }
    else
      -- Otherwise, show all actions in current file with update status
      pickers.pick_current_actions()
    end
  end, {
    nargs = "?",
    complete = function()
      -- TODO: Add completion for known actions
      return {}
    end,
    desc = "Show GitHub Actions in current file with update status (or browse versions for specific action)",
  })

  -- GhActionsSecure - Secure action by pinning to specific version
  vim.api.nvim_create_user_command("GhActionsSecure", function(opts)
    local versions = require_or_notify "ghactions.github.versions"
    if not versions then
      return
    end

    local pickers = require_or_notify "ghactions.telescope.pickers"
    if not pickers then
      return
    end

    local line = vim.fn.line "."
    local content = vim.fn.getline(line)

    -- Look for YAML action pattern: uses: owner/repo@version
    local action_match = content:match "uses:%s*[\"']?([^\"'%s]+)[\"']?"
    if not action_match then
      vim.notify("No GitHub Action found on current line", vim.log.levels.WARN)
      return
    end

    local action_name = versions.parse_action_name(action_match)
    if not action_name then
      vim.notify("Invalid action format", vim.log.levels.ERROR)
      return
    end

    pickers.pick_versions {
      action_name = action_name,
      on_select = function(version_entry)
        -- Use the consistent version selection logic: release->SHA, tag->tag name
        local new_version, is_sha = versions.get_version_for_update(version_entry)
        
        if not new_version then
          vim.notify("Could not determine version for " .. version_entry.version, vim.log.levels.ERROR)
          return
        end

        local new_action = action_name .. "@" .. new_version

        -- Replace the action in YAML format, preserving quote style if present
        local new_line
        if content:match "uses:%s*[\"']" then
          -- With quotes
          local quote_char = content:match "uses:%s*([\"'])"
          new_line = content:gsub("uses:%s*[\"'][^\"'%s]+[\"']?", "uses: " .. quote_char .. new_action .. quote_char)
        else
          -- Without quotes
          new_line = content:gsub("uses:%s*[^\"'%s]+", "uses: " .. new_action)
        end

        -- Add comment with tag name at the end of the line
        local comment = " # " .. version_entry.version
        new_line = new_line:gsub("%s*$", "") .. comment

        vim.fn.setline(line, new_line)
        
        local version_type = is_sha and "commit" or "tag"
        vim.notify(
          "Secured " .. action_name .. " to " .. version_type .. ": " .. new_version .. 
          (is_sha and " (" .. version_entry.version .. ")" or ""),
          vim.log.levels.INFO
        )
      end,
    }
  end, {
    desc = "Secure GitHub Action (release→SHA, tag→tag name)",
  })

  -- GhActionsUnsecure - Unsecure action by reverting to tag
  vim.api.nvim_create_user_command("GhActionsUnsecure", function(opts)
    local versions = require_or_notify "ghactions.github.versions"
    if not versions then
      return
    end

    local line = vim.fn.line "."
    local content = vim.fn.getline(line)

    -- Look for YAML action pattern: uses: owner/repo@version
    local action_match = content:match "uses:%s*[\"']?([^\"'%s]+)[\"']?"
    if not action_match then
      vim.notify("No GitHub Action found on current line", vim.log.levels.WARN)
      return
    end

    local action_name = versions.parse_action_name(action_match)
    if not action_name then
      vim.notify("Invalid action format", vim.log.levels.ERROR)
      return
    end

    -- Extract the original version from the comment if present
    -- Check for comment both inside and outside quotes
    local original_version = content:match("#%s*v[%d%.%w%-]*") or content:match("#%s*v[%d%.%w%-]*$")
    if original_version then
      -- Remove the '# ' prefix to get just the version
      original_version = original_version:gsub("^#%s*", "")
    else
      -- If no comment is found, fall back to latest version
      original_version = versions.get_latest_version(action_name)
      if not original_version then
        vim.notify("Could not determine original version and no latest version found", vim.log.levels.ERROR)
        return
      end
    end

    local new_action = action_name .. "@" .. original_version

    -- Replace the action in YAML format, preserving quote style if present
    local new_line
    if content:match "uses:%s*[\"']" then
      -- With quotes
      local quote_char = content:match "uses:%s*([\"'])"
      new_line = content:gsub("uses:%s*[\"'][^\"'%s]+[\"']?", "uses: " .. quote_char .. new_action .. quote_char)
    else
      -- Without quotes
      new_line = content:gsub("uses:%s*[^\"'%s]+", "uses: " .. new_action)
    end

    -- Remove the comment added by GhActionsSecure if present (format: # version)
    -- Matches patterns like: # v5, # v5.0, # v5.0.0, # v1.2.3-beta, etc.
    -- Handle both comments inside and outside quotes
    new_line = new_line:gsub("%s*#%s*v[%d%.%w%-]*", "")
    new_line = new_line:gsub('"%s*$', '"')  -- Clean up trailing whitespace inside quotes

    vim.fn.setline(line, new_line)
    vim.notify("Unsecured action to version: " .. new_action, vim.log.levels.INFO)
  end, {
    desc = "Unsecure GitHub Action to use tag",
  })

  -- GhActionsCachePurge - Clear cache
  vim.api.nvim_create_user_command("GhActionsCachePurge", function(opts)
    local cache = require_or_notify "ghactions.cache"
    if not cache then
      return
    end

    local stats = cache.stats()
    local confirm = vim.fn.confirm(string.format("Clear cache? (%d entries)", stats.size), "&Yes\n&No", 2)

    if confirm == 1 then
      cache.clear()
      vim.notify("Cache cleared", vim.log.levels.INFO)
    end
  end, {
    desc = "Clear GitHub Actions cache",
  })

  -- GhActionsCacheStats - Show cache statistics
  vim.api.nvim_create_user_command("GhActionsCacheStats", function(opts)
    local cache = require_or_notify "ghactions.cache"
    if not cache then
      return
    end

    local stats = cache.stats()
    local message = string.format(
      "Cache Statistics:\n" .. "  Size: %d/%d entries\n" .. "  TTL: %d seconds\n" .. "  Memory cache: %d entries",
      stats.size,
      stats.max_size,
      stats.ttl,
      stats.memory_size
    )
    vim.notify(message, vim.log.levels.INFO)
  end, {
    desc = "Show GitHub Actions cache statistics",
  })

  -- GhActionsSecureAll - Secure every action in current buffer
  vim.api.nvim_create_user_command("GhActionsSecureAll", function()
    local secure_all = require_or_notify "ghactions.secure_all"
    if not secure_all then
      return
    end
    secure_all.secure_all()
  end, {
    desc = "Secure all GitHub Actions in current buffer",
  })

  -- GhActionsUnsecureAll - Unsecure every action in current buffer
  vim.api.nvim_create_user_command("GhActionsUnsecureAll", function()
    local secure_all = require_or_notify "ghactions.secure_all"
    if not secure_all then
      return
    end
    secure_all.unsecure_all()
  end, {
    desc = "Unsecure all GitHub Actions in current buffer",
  })

  -- GhActions - Main command with subcommands

  vim.api.nvim_create_user_command("GhActions", function(opts)
    local subcommand = opts.args and opts.args:match "^%w+" or ""

    if subcommand == "versions" then
      local action_name = opts.args:match "^versions%s+(.+)$"
      vim.cmd("GhActionsVersions" .. (action_name and " " .. action_name or ""))
    elseif subcommand == "secure" then
      vim.cmd "GhActionsSecure"
    elseif subcommand == "unsecure" then
      vim.cmd "GhActionsUnsecure"
    elseif subcommand == "secure-all" then
      vim.cmd "GhActionsSecureAll"
    elseif subcommand == "unsecure-all" then
      vim.cmd "GhActionsUnsecureAll"
    elseif subcommand == "cache" then
      local cache_subcommand = opts.args:match "^cache%s+(%w+)"
      if cache_subcommand == "purge" then
        vim.cmd "GhActionsCachePurge"
      elseif cache_subcommand == "stats" then
        vim.cmd "GhActionsCacheStats"
      else
        vim.notify("Usage: GhActions cache [purge|stats]", vim.log.levels.ERROR)
      end
    else
      -- Show help
      local help = [[
GitHub Actions Plugin Commands:

  GhActions versions [action]    - Show actions in current file with update status (or browse versions for specific action)
  GhActions secure               - Secure action on current line
  GhActions unsecure             - Unsecure action on current line
  GhActions secure-all           - Secure every action in current buffer
  GhActions unsecure-all         - Unsecure every action in current buffer
  GhActions cache purge          - Clear cache
  GhActions cache stats          - Show cache statistics

Configuration:
  require('ghactions').setup({})

Individual commands:
  :GhActionsVersions [action]    - Show current file actions with update status, or browse versions for specific action
  :GhActionsSecure               - Secure action on current line (release→SHA, tag→tag name)
  :GhActionsUnsecure             - Unsecure action on current line to its tag
  :GhActionsSecureAll            - Secure all actions in current buffer
  :GhActionsUnsecureAll          - Unsecure all actions in current buffer
  :GhActionsCachePurge           - Clear GitHub Actions cache
  :GhActionsCacheStats           - Show cache statistics
      ]]
      vim.notify(help, vim.log.levels.INFO)
    end
  end, {
    nargs = "*",
    complete = function()
      return {
        "versions",
        "secure",
        "unsecure",
        "secure-all",
        "unsecure-all",
        "cache",
      }
    end,
    desc = "GitHub Actions management",
  })

  commands_created = true
end

-- Ensure commands are available even before setup is called
if not commands_created then
  M._create_commands()
end

-- Module info
M.version = "1.0.0"
M.name = "ghactions.nvim"

return M
