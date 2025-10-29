local M = {}

-- Dependencies
local client = require "ghactions.github.client"
local cache = require "ghactions.cache"

-- Parse action name from GitHub action reference
-- Examples: "actions/checkout@v3" -> "actions/checkout"
--          "github/super-linter@v4" -> "github/super-linter"
function M.parse_action_name(action_ref)
  if not action_ref then
    return nil
  end

  -- Extract owner/repo part before @
  local match = action_ref:match "^([^@]+)"
  return match
end

-- Parse version from action reference
-- Examples: "actions/checkout@v3" -> "v3"
--          "actions/checkout@abc123" -> "abc123"
function M.parse_version(action_ref)
  if not action_ref then
    return nil
  end

  -- Extract version after @
  local match = action_ref:match "@(.+)$"
  return match
end

-- Extract trailing comment version from a workflow line
-- Looks for comments like "# v3" or "# v3.5.0" and returns the version portion
function M.extract_comment_version(line)
  if not line then
    return nil
  end

  local comment = line:match "#%s*([%w%._%-%+/]+)%s*$"
  if comment then
    return vim.trim(comment)
  end

  return nil
end

-- Parse owner and repo from action name
-- Examples: "actions/checkout" -> "actions", "checkout"
function M.parse_owner_repo(action_name)
  if not action_name then
    return nil, nil
  end

  -- Handle both standard actions (owner/repo) and reusable workflows (owner/repo/.github/workflows/...)
  local owner, repo = action_name:match "^([^/]+)/([^/]+)"
  if not owner or not repo then
    return nil, nil
  end

  return owner, repo
end

-- Get action versions (releases and tags)
function M.get_action_versions(action_name, opts)
  opts = opts or {}

  local owner, repo = M.parse_owner_repo(action_name)
  if not owner or not repo then
    return nil, "Invalid action name format. Expected: owner/repo"
  end

  local cache_key = string.format("%s/%s", owner, repo)

  -- Check cache first
  if not opts.bypass_cache then
    local cached_versions = cache.get_action_versions(cache_key)
    if cached_versions then
      return cached_versions
    end
  end

  local github_client = client.new()
  local versions = {
    releases = {},
    tags = {},
    latest = nil,
  }

  -- Get releases
  local releases, err = github_client:get_releases(owner, repo, { per_page = 100 })
  if err then
    vim.notify("Failed to fetch releases: " .. err, vim.log.levels.WARN)
  else
    versions.releases = releases or {}
  end

  -- Get tags
  local tags, tag_err = github_client:get_tags(owner, repo, { per_page = 100 })
  if tag_err then
    vim.notify("Failed to fetch tags: " .. tag_err, vim.log.levels.WARN)
  else
    versions.tags = tags or {}
  end

  -- Determine latest version
  if #versions.releases > 0 then
    versions.latest = versions.releases[1].tag_name
  elseif #versions.tags > 0 then
    versions.latest = versions.tags[1].name
  end

  -- Cache the results at repository level so reusable workflows share data
  cache.set_action_versions(cache_key, versions)

  return versions
end

-- Get specific version information
function M.get_version_info(action_name, version)
  local versions = M.get_action_versions(action_name)
  if not versions then
    return nil
  end

  -- Check releases first
  for _, release in ipairs(versions.releases) do
    if release.tag_name == version then
      -- Find the corresponding tag for the commit SHA
      local commit_sha = nil
      for _, tag in ipairs(versions.tags) do
        if tag.name == version and tag.commit then
          commit_sha = tag.commit
          break
        end
      end

      return {
        type = "release",
        version = version,
        name = release.name,
        body = release.body,
        prerelease = release.prerelease,
        published_at = release.published_at,
        author = release.author,
        assets = release.assets,
        commit = commit_sha,
      }
    end
  end

  -- Check tags
  for _, tag in ipairs(versions.tags) do
    if tag.name == version then
      return {
        type = "tag",
        version = version,
        commit = {
          sha = tag.commit.sha,
          url = tag.commit.url,
        },
        zipball_url = tag.zipball_url,
        tarball_url = tag.tarball_url,
      }
    end
  end

  return nil
end

-- Get commit SHA for a specific version (tag or release)
function M.get_commit_sha_for_version(action_name, version)
  if not action_name or not version then
    return nil
  end

  local version_info = M.get_version_info(action_name, version)
  if not version_info then
    return nil
  end

  local commit = version_info.commit
  if type(commit) == "table" then
    return commit.sha
  elseif type(commit) == "string" then
    return commit
  end

  -- Fallback: check tags directly if commit info missing
  local versions = M.get_action_versions(action_name)
  if versions then
    for _, tag in ipairs(versions.tags) do
      if tag.name == version and tag.commit and tag.commit.sha then
        return tag.commit.sha
      end
    end
  end

  return nil
end

-- Compare two versions
-- Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
function M.compare_versions(v1, v2)
  if not v1 or not v2 then
    return nil
  end

  -- Handle SHA comparisons (direct string comparison)
  if v1:match "^%x+$" and v2:match "^%x+$" then
    if v1 < v2 then
      return -1
    elseif v1 > v2 then
      return 1
    else
      return 0
    end
  end

  -- Handle semantic version comparison
  local function parse_semver(version)
    -- Remove 'v' prefix if present
    version = version:gsub("^v", "")

    -- Extract major, minor, patch
    local major, minor, patch = version:match "^(%d+)%.?(%d*)%.?(%d*)"
    major = tonumber(major) or 0
    minor = tonumber(minor) or 0
    patch = tonumber(patch) or 0

    -- Extract prerelease and build metadata
    local prerelease = version:match "-(.+)$"

    return { major = major, minor = minor, patch = patch, prerelease = prerelease }
  end

  local semver1 = parse_semver(v1)
  local semver2 = parse_semver(v2)

  -- Compare major version
  if semver1.major < semver2.major then
    return -1
  elseif semver1.major > semver2.major then
    return 1
  end

  -- Compare minor version
  if semver1.minor < semver2.minor then
    return -1
  elseif semver1.minor > semver2.minor then
    return 1
  end

  -- Compare patch version
  if semver1.patch < semver2.patch then
    return -1
  elseif semver1.patch > semver2.patch then
    return 1
  end

  -- Handle prerelease (prerelease < release)
  if semver1.prerelease and not semver2.prerelease then
    return -1
  elseif not semver1.prerelease and semver2.prerelease then
    return 1
  elseif semver1.prerelease and semver2.prerelease then
    if semver1.prerelease < semver2.prerelease then
      return -1
    elseif semver1.prerelease > semver2.prerelease then
      return 1
    end
  end

  return 0
end

-- Validate version format
function M.is_valid_version(version)
  if not version then
    return false
  end

  -- Check for SHA (40 hex characters)
  if version:match "^%x+$" and #version >= 7 then
    return true
  end

  -- Check for semantic version pattern
  if version:match "^v?%d+%.?%d*%.?%d*" then
    return true
  end

  return false
end

-- Format version for display
function M.format_version(version, info)
  if not version then
    return "Unknown"
  end

  local display = version

  -- Add type indicator
  if info then
    if info.type == "release" then
      display = display .. " (release)"
      if info.prerelease then
        display = display .. " [pre-release]"
      end
    elseif info.type == "tag" then
      display = display .. " (tag)"
    end
  end

  -- Add short SHA for long SHAs
  if version:match "^%x+$" and #version > 10 then
    display = version:sub(1, 10) .. "..."
  end

  return display
end

-- Get latest version for an action
function M.get_latest_version(action_name)
  local versions = M.get_action_versions(action_name)
  return versions and versions.latest or nil
end

-- Get latest major version (e.g., v5.x.x -> v5)
function M.get_latest_major_version(action_name, current_major_version)
  local versions = M.get_action_versions(action_name)
  if not versions then
    return nil
  end

  -- Extract major version from current version (e.g., "v4" from "v4.1.0")
  local current_major = current_major_version:match "^v(%d+)"
  if not current_major then
    return versions.latest
  end

  -- Find the latest version with the same major version
  local latest_same_major = nil
  for _, version_entry in ipairs(M.get_sorted_versions(action_name)) do
    local entry_major = version_entry.version:match "^v(%d+)"
    if entry_major == current_major then
      latest_same_major = version_entry.version
      break
    end
  end

  return latest_same_major or versions.latest
end

-- Check if version is newer than current
function M.is_newer_version(action_name, current_version, new_version)
  local comparison = M.compare_versions(current_version, new_version)
  return comparison == 1
end

-- Get all available versions sorted (newest first)
function M.get_sorted_versions(action_name)
  local versions = M.get_action_versions(action_name)
  if not versions then
    return {}
  end

  local all_versions = {}

  -- Add releases
  for _, release in ipairs(versions.releases) do
    -- Find the corresponding tag for the commit SHA
    local commit_sha = nil
    for _, tag in ipairs(versions.tags) do
      if tag.name == release.tag_name and tag.commit then
        commit_sha = tag.commit
        break
      end
    end

    table.insert(all_versions, {
      version = release.tag_name,
      type = "release",
      prerelease = release.prerelease,
      published_at = release.published_at,
      commit = commit_sha,
      info = release,
    })
  end

  -- Add tags (that aren't already releases)
  local release_versions = {}
  for _, release in ipairs(versions.releases) do
    release_versions[release.tag_name] = true
  end

  for _, tag in ipairs(versions.tags) do
    if not release_versions[tag.name] then
      table.insert(all_versions, {
        version = tag.name,
        type = "tag",
        commit = tag.commit,
        info = tag,
      })
    end
  end

  -- Sort by version (newest first)
  table.sort(all_versions, function(a, b)
    return M.compare_versions(a.version, b.version) == 1
  end)

  return all_versions
end

-- Find all GitHub Actions in the current buffer
function M.find_actions_in_buffer()
  local actions = {}
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for line_num, line in ipairs(lines) do
    -- Look for YAML action pattern: uses: owner/repo@version
    local action_match = line:match "uses:%s*[\"']?([^\"'%s]+)[\"']?"
    if action_match then
      local action_name = M.parse_action_name(action_match)
      local current_version = M.parse_version(action_match)

      if action_name and current_version then
        local comment_version = M.extract_comment_version(line)
        table.insert(actions, {
          action_name = action_name,
          current_version = current_version,
          current_version_type = M.is_commit_sha(current_version) and "sha" or "tag",
          line_number = line_num,
          full_line = line,
          original_version = comment_version or current_version,
          comment_version = comment_version,
          has_comment = comment_version ~= nil,
        })
      end
    end
  end

  return actions
end

-- Consolidate duplicate actions in the list
function M.consolidate_duplicate_actions(actions)
  local consolidated = {}
  local action_map = {}

  -- Group actions by action_name
  for _, action in ipairs(actions) do
    local action_name = action.action_name
    if not action_map[action_name] then
      action_map[action_name] = {
        action_name = action_name,
        line_numbers = {},
        occurrences = {},
        current_versions = {},
        current_version_types = {},
        full_lines = {},
        original_versions = {},
        comment_versions = {},
        has_comments = {},
      }
    end

    local group = action_map[action_name]
    table.insert(group.line_numbers, action.line_number)
    table.insert(group.occurrences, action)
    table.insert(group.current_versions, action.current_version)
    table.insert(group.current_version_types, action.current_version_type)
    table.insert(group.full_lines, action.full_line)
    table.insert(group.original_versions, action.original_version)
    table.insert(group.comment_versions, action.comment_version)
    table.insert(group.has_comments, action.has_comment)
  end

  -- Convert groups back to consolidated format
  for action_name, group in pairs(action_map) do
    -- Use the first occurrence as the primary reference
    local primary = group.occurrences[1]

    -- Determine the most recent version for status checking
    local most_recent_version = primary.current_version
    local most_recent_version_type = primary.current_version_type
    local most_recent_index = 1

    -- Find the most recent version among all occurrences
    for i, version in ipairs(group.current_versions) do
      if M.compare_versions(version, most_recent_version) == 1 then
        most_recent_version = version
        most_recent_version_type = group.current_version_types[i]
        most_recent_index = i
      end
    end

    -- Create consolidated entry
    local consolidated_entry = {
      action_name = action_name,
      current_version = primary.current_version,
      current_version_type = primary.current_version_type,
      line_number = primary.line_number, -- Keep first line as primary
      line_numbers = group.line_numbers, -- All line numbers
      line_numbers_display = table.concat(group.line_numbers, ","), -- For display
      full_line = primary.full_line,
      original_version = primary.original_version,
      comment_version = primary.comment_version,
      has_comment = primary.has_comment,
      is_consolidated = #group.line_numbers > 1,
      occurrences = group.occurrences,
      most_recent_version = most_recent_version,
      most_recent_version_type = most_recent_version_type,
      most_recent_index = most_recent_index,
    }

    table.insert(consolidated, consolidated_entry)
  end

  return consolidated
end

-- Find all GitHub Actions in a specific file
function M.find_actions_in_file(filepath)
  local actions = {}

  -- Read file content
  local file = io.open(filepath, "r")
  if not file then
    return actions
  end

  local line_num = 0
  for line in file:lines() do
    line_num = line_num + 1

    -- Look for YAML action pattern: uses: owner/repo@version
    local action_match = line:match "uses:%s*[\"']?([^\"'%s]+)[\"']?"
    if action_match then
      local action_name = M.parse_action_name(action_match)
      local current_version = M.parse_version(action_match)

      if action_name and current_version then
        local comment_version = M.extract_comment_version(line)
        table.insert(actions, {
          action_name = action_name,
          current_version = current_version,
          current_version_type = M.is_commit_sha(current_version) and "sha" or "tag",
          line_number = line_num,
          full_line = line,
          original_version = comment_version or current_version,
          comment_version = comment_version,
          has_comment = comment_version ~= nil,
        })
      end
    end
  end

  file:close()
  return actions
end

-- Check if a version string is a commit SHA
function M.is_commit_sha(version)
  if not version then
    return false
  end

  -- Check if it matches SHA pattern (7-40 hex characters)
  local matches = version:match "^%x+$"
  local length_ok = #version >= 7 and #version <= 40
  return matches and length_ok or false
end

-- Get the version to use for updates based on type
-- If type is "release" -> use commit SHA for reproducibility
-- If type is "tag" -> use tag name for readability
function M.get_version_for_update(version_entry)
  if not version_entry then
    return nil
  end

  if version_entry.type == "release" then
    -- For releases, use the commit SHA for reproducibility
    if version_entry.commit and version_entry.commit.sha then
      return version_entry.commit.sha, true -- is_sha = true
    end
    -- Fallback to tag name if SHA not available
    return version_entry.version, false
  elseif version_entry.type == "tag" then
    -- For tags, use the tag name for readability
    return version_entry.version, false -- is_sha = false
  else
    -- Unknown type, use version as-is
    return version_entry.version, M.is_commit_sha(version_entry.version)
  end
end

-- Get update status for an action
function M.get_update_status(action_name, current_version)
  if not action_name or not current_version then
    return {
      status = "unknown",
      latest_version = nil,
      latest_version_type = nil,
    }
  end

  -- Get latest version
  local latest_version = M.get_latest_version(action_name)
  if not latest_version then
    return {
      status = "unknown",
      latest_version = nil,
      latest_version_type = nil,
    }
  end

  -- Determine the actual type of the latest version (release vs tag)
  local latest_version_type = "tag" -- default
  local versions = M.get_action_versions(action_name)
  if versions then
    -- Check if latest version is a release
    for _, release in ipairs(versions.releases) do
      if release.tag_name == latest_version then
        latest_version_type = "release"
        break
      end
    end
  end

  -- If current version is a SHA, we need to compare against the latest tag's SHA
  if M.is_commit_sha(current_version) then
    -- Get the latest release info to compare SHAs
    local latest_release_info = M.get_version_info(action_name, latest_version)
    if latest_release_info and latest_release_info.commit and latest_release_info.commit.sha then
      if
        current_version == latest_release_info.commit.sha
        or current_version:sub(1, 7) == latest_release_info.commit.sha:sub(1, 7)
      then
        return {
          status = "up_to_date",
          latest_version = latest_version,
          latest_version_type = latest_version_type,
        }
      else
        return {
          status = "update_available",
          latest_version = latest_version,
          latest_version_type = latest_version_type,
        }
      end
    end
  else
    -- Current version is a tag, need to handle semantic versioning
    -- Check if current version is a major version (like "v4")
    local is_major_version = current_version:match "^v%d+$"

    if is_major_version then
      -- For major versions, compare against the latest version in the same major series
      local latest_same_major = M.get_latest_major_version(action_name, current_version)
      if latest_same_major then
        -- Get the actual latest version to see if there's a newer major version
        local latest_info = M.get_version_info(action_name, latest_version)
        local latest_same_major_info = M.get_version_info(action_name, latest_same_major)

        if latest_same_major_info and latest_info then
          local current_major = current_version:match "^v(%d+)"
          local latest_major = latest_version:match "^v(%d+)"

          if current_major and latest_major then
            current_major = tonumber(current_major)
            latest_major = tonumber(latest_major)

            if current_major >= latest_major then
              -- User is on the latest major version
              return {
                status = "up_to_date",
                latest_version = latest_same_major,
                latest_version_type = latest_version_type,
              }
            else
              -- There's a newer major version available
              return {
                status = "update_available",
                latest_version = latest_version,
                latest_version_type = latest_version_type,
              }
            end
          end
        end
      end
    end

    -- For exact version tags or fallback
    if current_version == latest_version then
      return {
        status = "up_to_date",
        latest_version = latest_version,
        latest_version_type = latest_version_type,
      }
    else
      return {
        status = "update_available",
        latest_version = latest_version,
        latest_version_type = latest_version_type,
      }
    end
  end

  return {
    status = "unknown",
    latest_version = latest_version,
    latest_version_type = latest_version_type,
  }
end

-- Enrich actions with update status information
function M.enrich_actions_with_status(actions)
  if not actions then
    return {}
  end

  for _, action in ipairs(actions) do
    -- For consolidated actions, use most_recent_version for status checking
    local version_for_status = action.most_recent_version or action.current_version
    local status_info = M.get_update_status(action.action_name, version_for_status)
    action.latest_version = status_info.latest_version
    action.latest_version_type = status_info.latest_version_type
    action.status = status_info.status
  end

  return actions
end

return M
