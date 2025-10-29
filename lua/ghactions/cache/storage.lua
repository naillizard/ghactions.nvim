local M = {}

-- Dependencies
local config = require "ghactions.config"
local plenary_path = require "plenary.path"
local plenary_scandir = require "plenary.scandir"

-- Cache storage backend
local Cache = {}
Cache.__index = Cache

-- Create new cache instance
function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Cache)

  -- Cache configuration
  self.cache_dir = opts.cache_dir or vim.fn.stdpath "cache" .. "/ghactions.nvim"
  self.ttl = opts.ttl or config.get("cache.ttl", 3600)
  self.max_size = opts.max_size or config.get("cache.max_size", 1000)

  -- Ensure cache directory exists
  plenary_path:new(self.cache_dir):mkdir { parents = true }

  -- In-memory cache for performance
  self.memory_cache = {}

  return self
end

-- Generate cache file path for key
function Cache:_get_cache_path(key)
  local keys = require "ghactions.cache.keys"
  local sanitized_key = keys.sanitize_key(key)
  return self.cache_dir .. "/" .. sanitized_key .. ".json"
end

-- Get current timestamp
function Cache:_current_time()
  return os.time()
end

-- Check if cache entry is expired
function Cache:_is_expired(entry)
  if not entry or not entry.timestamp then
    return true
  end
  return (self:_current_time() - entry.timestamp) > self.ttl
end

-- Get value from cache
function Cache:get(key)
  -- Check memory cache first
  local memory_entry = self.memory_cache[key]
  if memory_entry and not self:_is_expired(memory_entry) then
    return memory_entry.value
  end

  -- Check file cache
  local cache_path = self:_get_cache_path(key)
  local cache_file = plenary_path:new(cache_path)

  if not cache_file:exists() then
    return nil
  end

  local ok, data = pcall(vim.json.decode, cache_file:read())
  if not ok or not data then
    return nil
  end

  -- Check if expired
  if self:_is_expired(data) then
    cache_file:rm()
    return nil
  end

  -- Update memory cache
  self.memory_cache[key] = data

  return data.value
end

-- Set value in cache
function Cache:set(key, value)
  local entry = {
    value = value,
    timestamp = self:_current_time(),
  }

  -- Update memory cache
  self.memory_cache[key] = entry

  -- Write to file cache
  local cache_path = self:_get_cache_path(key)
  local cache_file = plenary_path:new(cache_path)

  local ok, json_data = pcall(vim.json.encode, entry)
  if not ok then
    vim.notify("Failed to encode cache data", vim.log.levels.ERROR)
    return false
  end

  cache_file:write(json_data, "w")

  -- Cleanup if needed
  self:_cleanup_if_needed()

  return true
end

-- Delete value from cache
function Cache:delete(key)
  -- Remove from memory cache
  self.memory_cache[key] = nil

  -- Remove from file cache
  local cache_path = self:_get_cache_path(key)
  local cache_file = plenary_path:new(cache_path)
  if cache_file:exists() then
    cache_file:rm()
  end
end

-- Clear all cache
function Cache:clear()
  -- Clear memory cache
  self.memory_cache = {}

  -- Clear file cache
  local cache_dir = plenary_path:new(self.cache_dir)
  if cache_dir:exists() then
    cache_dir:rm { recursive = true }
    cache_dir:mkdir { parents = true }
  end
end

-- Get cache size (number of entries)
function Cache:size()
  local count = 0
  local cache_dir = plenary_path:new(self.cache_dir)

  if cache_dir:exists() then
    local files = plenary_scandir.scan_dir(self.cache_dir, {
      hidden = false,
      add_dirs = false,
    })
    for _, file in ipairs(files) do
      if file:match "%.json$" then
        count = count + 1
      end
    end
  end

  return count
end

-- Cleanup expired entries
function Cache:_cleanup_expired()
  local cache_dir = plenary_path:new(self.cache_dir)
  if not cache_dir:exists() then
    return
  end

  local files = plenary_scandir.scan_dir(self.cache_dir, {
    hidden = false,
    add_dirs = false,
  })
  local current_time = self:_current_time()

  for _, file_path in ipairs(files) do
    if file_path:match "%.json$" then
      local file = plenary_path:new(file_path)
      local ok, data = pcall(vim.json.decode, file:read())
      if ok and data and data.timestamp then
        if (current_time - data.timestamp) > self.ttl then
          file:rm()
          -- Also remove from memory cache
          local key = file_path:match "([^/]+)%.json$"
          self.memory_cache[key] = nil
        end
      end
    end
  end
end

-- Cleanup if cache exceeds max size
function Cache:_cleanup_if_needed()
  if self:size() <= self.max_size then
    return
  end

  -- First cleanup expired entries
  self:_cleanup_expired()

  -- If still too large, remove oldest entries
  if self:size() > self.max_size then
    local entries = {}
    local cache_dir = plenary_path:new(self.cache_dir)

    -- Collect all entries with timestamps
    local files = plenary_scandir.scan_dir(self.cache_dir, {
      hidden = false,
      add_dirs = false,
    })
    for _, file_path in ipairs(files) do
      if file_path:match "%.json$" then
        local file = plenary_path:new(file_path)
        local ok, data = pcall(vim.json.decode, file:read())
        if ok and data and data.timestamp then
          table.insert(entries, {
            file = file,
            timestamp = data.timestamp,
            key = file_path:match "([^/]+)%.json$",
          })
        end
      end
    end

    -- Sort by timestamp (oldest first)
    table.sort(entries, function(a, b)
      return a.timestamp < b.timestamp
    end)

    -- Remove oldest entries until under limit
    local to_remove = #entries - self.max_size + 1
    for i = 1, to_remove do
      if entries[i] then
        entries[i].file:rm()
        self.memory_cache[entries[i].key] = nil
      end
    end
  end
end

-- Get cache statistics
function Cache:stats()
  local stats = {
    size = self:size(),
    max_size = self.max_size,
    ttl = self.ttl,
    memory_size = vim.tbl_count(self.memory_cache),
  }

  return stats
end

return M
