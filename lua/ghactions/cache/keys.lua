local M = {}

-- Generate cache key for GitHub API requests
function M.github_api_key(owner, repo, endpoint, params)
  params = params or {}

  -- Sort params for consistent key generation
  local sorted_params = {}
  for k, v in pairs(params) do
    table.insert(sorted_params, k .. "=" .. tostring(v))
  end
  table.sort(sorted_params)

  local param_string = table.concat(sorted_params, "&")

  return string.format("github_api:%s:%s:%s:%s", owner, repo, endpoint, param_string)
end

-- Generate cache key for action versions
function M.action_versions_key(action_name)
  local key = string.format("action_versions:%s", action_name)
  return M.sanitize_key(key)
end

-- Generate cache key for action releases
function M.action_releases_key(action_name)
  local key = string.format("action_releases:%s", action_name)
  return M.sanitize_key(key)
end

-- Generate cache key for workflow files
function M.workflows_key(owner, repo)
  return string.format("workflows:%s:%s", owner, repo)
end

-- Generate cache key for workflow content
function M.workflow_content_key(owner, repo, workflow_id)
  return string.format("workflow_content:%s:%s:%s", owner, repo, workflow_id)
end

-- Generate cache key for repository info
function M.repo_info_key(owner, repo)
  return string.format("repo_info:%s:%s", owner, repo)
end

-- Generate cache key for user info
function M.user_info_key(username)
  return string.format("user_info:%s", username)
end

-- Generate cache key for search results
function M.search_key(query, type, params)
  params = params or {}

  -- Sort params for consistent key generation
  local sorted_params = {}
  for k, v in pairs(params) do
    table.insert(sorted_params, k .. "=" .. tostring(v))
  end
  table.sort(sorted_params)

  local param_string = table.concat(sorted_params, "&")

  return string.format("search:%s:%s:%s", type, query, param_string)
end

-- Generate cache key for rate limit info
function M.rate_limit_key()
  return "rate_limit:github"
end

-- Generate cache key for pinned actions
function M.pinned_actions_key()
  return "pinned_actions:list"
end

-- Generate cache key for action metadata
function M.action_metadata_key(action_name, version)
  return string.format("action_metadata:%s:%s", action_name, version)
end

-- Sanitize key to be filesystem-safe
function M.sanitize_key(key)
  -- Replace problematic characters with underscores
  return key:gsub("[^%w_%-%.]", "_"):gsub("__+", "_")
end

-- Generate a unique key from any table of parameters
function M.generate_key(prefix, params)
  params = params or {}

  -- Convert params to sorted string
  local sorted_params = {}
  for k, v in pairs(params) do
    if type(v) == "table" then
      v = vim.json.encode(v)
    end
    table.insert(sorted_params, k .. "=" .. tostring(v))
  end
  table.sort(sorted_params)

  local param_string = table.concat(sorted_params, "&")
  local raw_key = prefix .. ":" .. param_string

  return M.sanitize_key(raw_key)
end

return M
