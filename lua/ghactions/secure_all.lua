local M = {}

local versions = require "ghactions.github.versions"

local function secure_actions(actions)
  local secured_count = 0
  local failed_count = 0
  local skipped_count = 0

  for _, action in ipairs(actions) do
    local success, result = pcall(function()
      if action.current_version_type == "sha" and action.comment_version then
        -- Skip if already secured with a comment (can unsecure later)
        skipped_count = skipped_count + 1
        return { processed = false, skipped = true }
      end

      local target_version = action.current_version
      -- Use comment version if available (from old secure), otherwise use current version
      local version_to_secure = action.comment_version or target_version
      local commit_sha = versions.get_commit_sha_for_version(action.action_name, version_to_secure)
      if not commit_sha then
        skipped_count = skipped_count + 1
        vim.notify(
          "Skipping " .. action.action_name .. ": could not resolve SHA for " .. target_version,
          vim.log.levels.WARN
        )
        return { processed = false, skipped = true }
      end

      local current_line = vim.fn.getline(action.line_number)
      local new_action = action.action_name .. "@" .. commit_sha

      -- Update the action to use SHA
      local new_line = versions.update_action_in_line(current_line, new_action)

      -- Add comment with original version to allow unsecuring later
      if not current_line:match("#.*") then
        new_line = new_line:gsub("%s*$", "") .. " # " .. version_to_secure
      end

      vim.fn.setline(action.line_number, new_line)
      return { processed = true, skipped = false }
    end)

    if success then
      if result and result.processed then
        secured_count = secured_count + 1
      end
    else
      failed_count = failed_count + 1
      vim.notify("Failed to secure " .. action.action_name .. ": " .. tostring(result), vim.log.levels.ERROR)
    end
  end

  return secured_count, failed_count, skipped_count
end

local function unsecure_actions(actions)
  local unsecured_count = 0
  local failed_count = 0
  local skipped_count = 0

  for _, action in ipairs(actions) do
    local success, result = pcall(function()
      if action.current_version_type ~= "sha" then
        skipped_count = skipped_count + 1
        return { processed = false, skipped = true }
      end

      local original_version = action.comment_version or action.original_version
      if not original_version or original_version == "" or M.is_commit_sha(original_version) then
        skipped_count = skipped_count + 1
        vim.notify(
          "Skipping " .. action.action_name .. ": missing original tag version",
          vim.log.levels.WARN
        )
        return { processed = false, skipped = true }
      end

      local current_line = vim.fn.getline(action.line_number)
      local new_action = action.action_name .. "@" .. original_version

      -- Remove any existing comment before updating
      local line_without_comment = current_line:gsub("%s*#.*$", "")

      local new_line = versions.update_action_in_line(line_without_comment, new_action)
      vim.fn.setline(action.line_number, new_line)
      return { processed = true, skipped = false }
    end)

    if success then
      if result and result.processed then
        unsecured_count = unsecured_count + 1
      end
    else
      failed_count = failed_count + 1
      vim.notify("Failed to unsecure " .. action.action_name .. ": " .. tostring(result), vim.log.levels.ERROR)
    end
  end

  return unsecured_count, failed_count, skipped_count
end

local function refresh_views()
  vim.defer_fn(function()
    local refreshed_actions = versions.find_actions_in_buffer()
    if refreshed_actions and #refreshed_actions > 0 then
      versions.enrich_actions_with_status(refreshed_actions)
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(0) then
          vim.cmd("doautocmd User GhActionsRefresh")
        end
      end, 100)
    end
  end, 50)
end

function M.secure_all()
  local actions = versions.find_actions_in_buffer()
  if not actions or #actions == 0 then
    vim.notify("No GitHub Actions found in current buffer", vim.log.levels.WARN)
    return
  end

  actions = versions.enrich_actions_with_status(actions)

  local secured_count, failed_count, skipped_count = secure_actions(actions)
  local message = string.format("Secured %d actions with commit SHAs", secured_count)

  if failed_count > 0 then
    message = message .. string.format("\nFailed to secure %d actions", failed_count)
  end

  if skipped_count > 0 then
    message = message .. string.format("\nSkipped %d actions (already secured or missing info)", skipped_count)
  end

  vim.notify(message, secured_count > 0 and vim.log.levels.INFO or vim.log.levels.WARN)
  refresh_views()
end

function M.unsecure_all()
  local actions = versions.find_actions_in_buffer()
  if not actions or #actions == 0 then
    vim.notify("No GitHub Actions found in current buffer", vim.log.levels.WARN)
    return
  end

  actions = versions.enrich_actions_with_status(actions)

  local unsecured_count, failed_count, skipped_count = unsecure_actions(actions)
  local message = string.format("Unsecured %d actions back to tagged versions", unsecured_count)

  if failed_count > 0 then
    message = message .. string.format("\nFailed to unsecure %d actions", failed_count)
  end

  if skipped_count > 0 then
    message = message .. string.format("\nSkipped %d actions (not secured or missing info)", skipped_count)
  end

  vim.notify(message, unsecured_count > 0 and vim.log.levels.INFO or vim.log.levels.WARN)
  refresh_views()
end

return M
