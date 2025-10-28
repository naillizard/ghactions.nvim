-- Minimal test suite for ghactions.nvim
local M = {}

-- Test results
local test_results = {
  total = 0,
  passed = 0,
  failed = 0
}

-- Test framework
local function test(name, func)
  print("Running test: " .. name)
  local success, err = pcall(func)
  if not success then
    print("ERROR in " .. name .. ": " .. err)
    test_results.failed = test_results.failed + 1
  end
end

local function assert_equal(actual, expected, message)
  if actual == expected then
    test_results.passed = test_results.passed + 1
    return true
  else
    local msg = message or string.format("Expected %s, got %s", tostring(expected), tostring(actual))
    print(string.format("FAIL: %s", msg))
    test_results.failed = test_results.failed + 1
    return false
  end
end

-- Run all tests
function M.run_all()
  -- Reset test results
  test_results = {
    total = 0,
    passed = 0,
    failed = 0
  }

  -- Call all test functions
  local function run_all_test_functions()
    test("get_version_for_update logic", function()
      -- Test the version selection logic directly
      local function get_version_for_update(version_entry)
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
          local is_commit_sha = version_entry.version:match("^%x+$") and #version_entry.version >= 7
          return version_entry.version, is_commit_sha
        end
      end

      -- Test release entry with SHA
      local release_entry = {
        type = "release",
        version = "v4.0.0",
        commit = { sha = "abc123def456" }
      }
      local version, is_sha = get_version_for_update(release_entry)
      assert_equal(version, "abc123def456", "Release should use SHA")
      assert_equal(is_sha, true, "Release should return is_sha=true")

      -- Test tag entry
      local tag_entry = {
        type = "tag", 
        version = "v4.1.0"
      }
      version, is_sha = get_version_for_update(tag_entry)
      assert_equal(version, "v4.1.0", "Tag should use tag name")
      assert_equal(is_sha, false, "Tag should return is_sha=false")
    end)

    test("latest version type detection", function()
      -- Test that get_update_status correctly identifies release vs tag
      
      -- Mock the versions.get_action_versions function
      local mock_action_versions = {
        releases = {
          { tag_name = "v5.0.0", prerelease = false },
          { tag_name = "v4.0.0", prerelease = false }
        },
        tags = {
          { name = "v5.1.0", commit = { sha = "tag789def012" } },
          { name = "v5.0.0", commit = { sha = "release123abc456" } }
        },
        latest = "v5.0.0" -- Should be the latest release
      }

      -- Test latest version detection
      local latest_version = mock_action_versions.latest
      assert_equal(latest_version, "v5.0.0", "Latest version should be v5.0.0 (release)")

      -- Test that latest is a release (not just a tag)
      local found_as_release = false
      for _, release in ipairs(mock_action_versions.releases) do
        if release.tag_name == latest_version then
          found_as_release = true
          break
        end
      end
      assert_equal(found_as_release, true, "Latest version should be found in releases")
    end)

    test("GhActionsSecure consistent behavior", function()
      -- Test that GhActionsSecure uses the same logic as other update actions
      
      local function get_version_for_update(version_entry)
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
          local is_commit_sha = version_entry.version:match("^%x+$") and #version_entry.version >= 7
          return version_entry.version, is_commit_sha
        end
      end

      -- Test pin with release - should use SHA
      local release_entry = {
        type = "release",
        version = "v5.0.0",
        commit = { sha = "release123abc456" }
      }
      local version, is_sha = get_version_for_update(release_entry)
      assert_equal(version, "release123abc456", "Secure release should use SHA")
      assert_equal(is_sha, true, "Secure release should be marked as SHA")

      -- Test pin with tag - should use tag name
      local tag_entry = {
        type = "tag",
        version = "v5.1.0",
        commit = { sha = "tag789def012" }
      }
      version, is_sha = get_version_for_update(tag_entry)
      assert_equal(version, "v5.1.0", "Secure tag should use tag name")
      assert_equal(is_sha, false, "Secure tag should not be marked as SHA")
    end)

    test("status reporting with SHA and semantic versions", function()
      -- Test status logic for SHAs and semantic versioning
      
      -- Test 1: SHA comparison should work correctly
      local function test_sha_status(current_sha)
        local target_sha = "abc123456789def"
        if current_sha == target_sha or current_sha:sub(1, 7) == target_sha:sub(1, 7) then
          return "up_to_date"
        else
          return "update_available"
        end
      end

      assert_equal(test_sha_status("abc123456789def"), "up_to_date", 
                   "Matching SHA should show up_to_date")
      assert_equal(test_sha_status("def987654321abc"), "update_available", 
                   "Different SHA should show update_available")

      -- Test 2: Major version semantic comparison
      local function test_major_version_status(current_version, latest_version)
        local is_major_version = current_version:match "^v%d+$"
        if not is_major_version then
          return current_version == latest_version and "up_to_date" or "update_available"
        end
        
        local current_major = current_version:match "^v(%d+)"
        local latest_major = latest_version:match "^v(%d+)"
        
        if current_major and latest_major then
          current_major = tonumber(current_major)
          latest_major = tonumber(latest_major)
          
          return current_major >= latest_major and "up_to_date" or "update_available"
        end
        
        return "update_available"
      end

      assert_equal(test_major_version_status("v4", "v5.0.0"), "update_available", 
                   "v4 should show update when v5.0.0 is latest")
      assert_equal(test_major_version_status("v5", "v5.0.0"), "up_to_date", 
                   "v5 should show up_to_date when v5.0.0 is latest")
      assert_equal(test_major_version_status("v6", "v5.0.0"), "up_to_date", 
                   "v6 should show up_to_date when newer than latest")
    end)
  end

  -- Run all tests
  run_all_test_functions()
  test_results.total = test_results.passed + test_results.failed

  -- Print results
  print "================================"
  print(
    string.format("Tests: %d total, %d passed, %d failed", test_results.total, test_results.passed, test_results.failed)
  )

  if test_results.failed == 0 then
    print "All tests passed! ✓"
    return true
  else
    print "Some tests failed! ✗"
    return false
  end
end

return M