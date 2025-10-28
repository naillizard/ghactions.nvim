local M = {}

-- Cache modules
local storage = require "ghactions.cache.storage"
local keys = require "ghactions.cache.keys"

-- Global cache instance
local cache_instance = nil

-- Initialize cache
function M.init(opts)
  if not cache_instance then
    cache_instance = storage.new(opts)
  end
  return cache_instance
end

-- Get cache instance
function M.get_instance()
  if not cache_instance then
    cache_instance = M.init()
  end
  return cache_instance
end

-- Get value from cache
function M.get(key)
  local instance = M.get_instance()
  return instance:get(key)
end

-- Set value in cache
function M.set(key, value)
  local instance = M.get_instance()
  return instance:set(key, value)
end

-- Delete value from cache
function M.delete(key)
  local instance = M.get_instance()
  return instance:delete(key)
end

-- Clear all cache
function M.clear()
  local instance = M.get_instance()
  return instance:clear()
end

-- Get cache statistics
function M.stats()
  local instance = M.get_instance()
  return instance:stats()
end

-- Convenience functions for common cache operations
function M.get_action_versions(action_name)
  local key = keys.action_versions_key(action_name)
  return M.get(key)
end

function M.set_action_versions(action_name, versions)
  local key = keys.action_versions_key(action_name)
  return M.set(key, versions)
end

function M.get_action_releases(action_name)
  local key = keys.action_releases_key(action_name)
  return M.get(key)
end

function M.set_action_releases(action_name, releases)
  local key = keys.action_releases_key(action_name)
  return M.set(key, releases)
end

function M.get_workflows(owner, repo)
  local key = keys.workflows_key(owner, repo)
  return M.get(key)
end

function M.set_workflows(owner, repo, workflows)
  local key = keys.workflows_key(owner, repo)
  return M.set(key, workflows)
end

function M.get_workflow_content(owner, repo, workflow_id)
  local key = keys.workflow_content_key(owner, repo, workflow_id)
  return M.get(key)
end

function M.set_workflow_content(owner, repo, workflow_id, content)
  local key = keys.workflow_content_key(owner, repo, workflow_id)
  return M.set(key, content)
end

function M.get_pinned_actions()
  local key = keys.pinned_actions_key()
  return M.get(key)
end

function M.set_pinned_actions(pinned_actions)
  local key = keys.pinned_actions_key()
  return M.set(key, pinned_actions)
end

function M.get_rate_limit()
  local key = keys.rate_limit_key()
  return M.get(key)
end

function M.set_rate_limit(rate_limit_info)
  local key = keys.rate_limit_key()
  return M.set(key, rate_limit_info)
end

return M
