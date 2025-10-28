local M = {}

-- Dependencies
local config = require "ghactions.config"
local cache = require "ghactions.cache"

-- GitHub API client
local Client = {}
Client.__index = Client

-- API base URL
local API_BASE_URL = "https://api.github.com"

-- Create new client instance
function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Client)

  -- Configuration
  self.timeout = opts.timeout or config.get("github.api_timeout", 10000)
  self.max_retries = opts.max_retries or config.get("github.max_retries", 3)
  self.token = opts.token or os.getenv "GITHUB_TOKEN"

  return self
end

-- Make HTTP request using GitHub CLI (gh api)
function Client:_request(method, url, opts)
  opts = opts or {}
  local headers = opts.headers or {}
  local body = opts.body
  local timeout = opts.timeout or self.timeout

  -- Build gh api command
  local gh_cmd = {
    "gh",
    "api",
    "--method",
    method,
  }

  -- Add headers
  for k, v in pairs(headers) do
    table.insert(gh_cmd, "-H")
    table.insert(gh_cmd, k .. ": " .. v)
  end

  -- Add body if present
  if body then
    table.insert(gh_cmd, "--input")
    table.insert(gh_cmd, "-") -- Read from stdin
  end

  -- Add URL (remove the base URL since gh api adds it)
  local endpoint = url:gsub("^https://api%.github%.com", "")
  table.insert(gh_cmd, endpoint)

  -- Execute command
  local cmd = table.concat(gh_cmd, " ")
  local handle

  if body then
    handle = io.popen(cmd, "w")
    handle:write(body)
    handle:close()
    return "", "Body requests not fully implemented"
  else
    handle = io.popen(cmd)
    local response = handle:read "*a"
    local success = handle:close()

    if not success then
      return nil, "Command failed"
    end

    return response
  end
end

-- Parse rate limit headers
function Client:_parse_rate_limit(headers)
  -- This is a simplified version - in practice we'd need to parse actual headers
  -- For now, we'll use the rate limit API endpoint
  return {
    limit = 5000,
    remaining = 4999,
    reset = os.time() + 3600,
  }
end

-- Check rate limit
function Client:check_rate_limit()
  local cache_key = "rate_limit:github"
  local cached_limit = cache.get(cache_key)

  if cached_limit and cached_limit.reset > os.time() then
    return cached_limit
  end

  local response, err = self:_request("GET", API_BASE_URL .. "/rate_limit")
  if err then
    -- Return a default rate limit if API call fails
    return {
      limit = 5000,
      remaining = 4000,
      reset = os.time() + 3600,
    }
  end

  local ok, data = pcall(vim.json.decode, response)
  if not ok then
    -- Return a default rate limit if parsing fails
    return {
      limit = 5000,
      remaining = 4000,
      reset = os.time() + 3600,
    }
  end

  local rate_limit = {
    limit = data.rate and data.rate.limit or 5000,
    remaining = data.rate and data.rate.remaining or 4000,
    reset = data.rate and data.rate.reset or (os.time() + 3600),
  }

  -- Cache for 5 minutes
  cache.set(cache_key, rate_limit)

  return rate_limit
end

-- Wait for rate limit reset if needed
function Client:_handle_rate_limit()
  local rate_limit, err = self:check_rate_limit()
  if err then
    return false, err
  end

  if rate_limit.remaining < 10 then
    local wait_time = rate_limit.reset - os.time()
    if wait_time > 0 then
      vim.notify(string.format("Rate limit low. Waiting %d seconds...", wait_time), vim.log.levels.WARN)
      os.execute("sleep " .. wait_time)
    end
  end

  return true
end

-- Make API request with retry logic
function Client:api_request(method, endpoint, opts)
  opts = opts or {}
  local url = API_BASE_URL .. endpoint

  -- Check rate limit first
  local ok, err = self:_handle_rate_limit()
  if not ok then
    return nil, err
  end

  local last_err = nil

  for attempt = 1, self.max_retries do
    local response, err = self:_request(method, url, opts)

    if err then
      last_err = err
      if attempt < self.max_retries then
        vim.notify(
          string.format("Request failed (attempt %d/%d): %s", attempt, self.max_retries, err),
          vim.log.levels.WARN
        )
        os.execute("sleep " .. (2 ^ attempt)) -- Exponential backoff
      end
    else
      -- Parse response
      local ok, data = pcall(vim.json.decode, response)
      if not ok then
        return nil, "Failed to parse response: " .. response
      end

      return data
    end
  end

  return nil, last_err or "Max retries exceeded"
end

-- Get repository information
function Client:get_repo(owner, repo)
  local endpoint = string.format("/repos/%s/%s", owner, repo)
  return self:api_request("GET", endpoint)
end

-- Get repository releases
function Client:get_releases(owner, repo, opts)
  opts = opts or {}
  local params = {}

  if opts.per_page then
    table.insert(params, "per_page=" .. opts.per_page)
  end

  if opts.page then
    table.insert(params, "page=" .. opts.page)
  end

  local endpoint = string.format("/repos/%s/%s/releases", owner, repo)
  if #params > 0 then
    endpoint = endpoint .. "?" .. table.concat(params, "&")
  end

  return self:api_request("GET", endpoint)
end

-- Get repository tags
function Client:get_tags(owner, repo, opts)
  opts = opts or {}
  local params = {}

  if opts.per_page then
    table.insert(params, "per_page=" .. opts.per_page)
  end

  if opts.page then
    table.insert(params, "page=" .. opts.page)
  end

  local endpoint = string.format("/repos/%s/%s/tags", owner, repo)
  if #params > 0 then
    endpoint = endpoint .. "?" .. table.concat(params, "&")
  end

  return self:api_request("GET", endpoint)
end

-- Get repository workflows
function Client:get_workflows(owner, repo)
  local endpoint = string.format("/repos/%s/%s/actions/workflows", owner, repo)
  return self:api_request("GET", endpoint)
end

-- Get workflow file content
function Client:get_workflow_file(owner, repo, workflow_id)
  local endpoint = string.format("/repos/%s/%s/actions/workflows/%s", owner, repo, workflow_id)
  return self:api_request("GET", endpoint)
end

-- Search repositories
function Client:search_repositories(query, opts)
  opts = opts or {}
  local params = { "q=" .. vim.uri_encode(query) }

  if opts.sort then
    table.insert(params, "sort=" .. opts.sort)
  end

  if opts.order then
    table.insert(params, "order=" .. opts.order)
  end

  if opts.per_page then
    table.insert(params, "per_page=" .. opts.per_page)
  end

  local endpoint = "/search/repositories?" .. table.concat(params, "&")
  return self:api_request("GET", endpoint)
end

-- Get user information
function Client:get_user(username)
  local endpoint = string.format("/users/%s", username or "")
  return self:api_request("GET", endpoint)
end

-- Get authenticated user information
function Client:get_current_user()
  return self:api_request("GET", "/user")
end

return M
