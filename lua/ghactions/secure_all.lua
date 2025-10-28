local M = {}

local versions = require "ghactions.github.versions"

local function secure_actions(actions)
  local secured_count = 0
  local failed_count = 0
  local skipped_count = 0

  for _, action in ipairs(actions) do
    local success, result = pcall(function()
      if action.current_version_type == "sha" then
        skipped_count = skipped_count + 1
        return { processed = false, skipped = true }
      end

      local target_version = action.current_version
      local commit_sha = versions.get_commit_sha_for_version(action.action_name, target_version)
      if not commit_sha then
        skipped_count = skipped_count + 1
        vim.notify(
          "Skipping " .. action.action_name .. ": could not resolve SHA for " .. target_version,
          vim.log.levels.WARN
        )
        return { processed = false, skipped = true }
      end

      local current_line = vim.fn.getline(action.line_number)
      local new_line = current_line:gsub("%s*#.*$", "")
      local new_action = action.action_name .. "@" .. commit_sha

      if current_line:match "uses:%s*[\"']" then
        local quote_char = current_line:match "uses:%s*([\"'])"
        new_line = new_line:gsub("uses:%s*[\"'][^\"'%s]+[\"']?", "uses: " .. quote_char .. new_action .. quote_char)
      else
        new_line = new_line:gsub("uses:%s*[^\"'%s]+", "uses: " .. new_action)
      end

      new_line = new_line:gsub("%s*$", "") .. " # " .. target_version
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
      if not original_version or original_version == "" then
        skipped_count = skipped_count + 1
        vim.notify(
          "Skipping " .. action.action_name .. ": missing original version comment",
          vim.log.levels.WARN
        )
        return { processed = false, skipped = true }
      end

      local current_line = vim.fn.getline(action.line_number)
      local new_line = current_line:gsub("%s*#.*$", "")
      local new_action = action.action_name .. "@" .. original_version

      if current_line:match "uses:%s*[\"']" then
        local quote_char = current_line:match "uses:%s*([\"'])"
        new_line = new_line:gsub("uses:%s*[\"'][^\"'%s]+[\"']?", "uses: " .. quote_char .. new_action .. quote_char)
      else
        new_line = new_line:gsub("uses:%s*[^\"'%s]+", "uses: " .. new_action)
      end

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
