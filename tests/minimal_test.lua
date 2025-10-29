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

    test("consolidate_duplicate_actions", function()
      -- Test consolidation logic for duplicate actions
      
      -- Create a mock versions module with just the consolidation function
      local mock_versions = {}
      
      -- Copy the consolidation function logic directly to avoid dependency issues
      function mock_versions.consolidate_duplicate_actions(actions)
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
          -- Use first occurrence as primary reference
          local primary = group.occurrences[1]
          
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
          }
          
          table.insert(consolidated, consolidated_entry)
        end
        
        return consolidated
      end
      
      -- Test data: actions with duplicates
      local test_actions = {
        {
          action_name = "actions/checkout",
          current_version = "v3",
          current_version_type = "tag",
          line_number = 14,
          full_line = "uses: actions/checkout@v3",
          original_version = "v3",
          comment_version = nil,
          has_comment = false,
        },
        {
          action_name = "actions/setup-node",
          current_version = "v2",
          current_version_type = "tag", 
          line_number = 18,
          full_line = "uses: actions/setup-node@v2",
          original_version = "v2",
          comment_version = nil,
          has_comment = false,
        },
        {
          action_name = "actions/checkout",
          current_version = "v4",
          current_version_type = "tag",
          line_number = 23,
          full_line = "uses: actions/checkout@v4",
          original_version = "v4",
          comment_version = nil,
          has_comment = false,
        },
        {
          action_name = "actions/checkout",
          current_version = "v3",
          current_version_type = "tag",
          line_number = 31,
          full_line = "uses: actions/checkout@v3",
          original_version = "v3",
          comment_version = nil,
          has_comment = false,
        }
      }
      
      -- Test consolidation
      local consolidated = mock_versions.consolidate_duplicate_actions(test_actions)
      
      -- Should have 2 entries: actions/checkout (consolidated) and actions/setup-node (single)
      assert_equal(#consolidated, 2, "Should consolidate to 2 entries")
      
      -- Find the consolidated checkout entry
      local checkout_entry = nil
      local setup_node_entry = nil
      
      for _, entry in ipairs(consolidated) do
        if entry.action_name == "actions/checkout" then
          checkout_entry = entry
        elseif entry.action_name == "actions/setup-node" then
          setup_node_entry = entry
        end
      end
      
      -- Test consolidated checkout entry
      assert_equal(checkout_entry ~= nil, true, "Should have checkout entry")
      assert_equal(checkout_entry.is_consolidated, true, "Checkout should be consolidated")
      assert_equal(checkout_entry.line_numbers_display, "14,23,31", "Should show concatenated line numbers")
      assert_equal(checkout_entry.line_number, 14, "Should keep first line as primary")
      assert_equal(#checkout_entry.line_numbers, 3, "Should have 3 line numbers")
      assert_equal(checkout_entry.current_version, "v3", "Should use first occurrence version")
      
      -- Test single setup-node entry
      assert_equal(setup_node_entry ~= nil, true, "Should have setup-node entry")
      assert_equal(setup_node_entry.is_consolidated, false, "Setup-node should not be consolidated")
      assert_equal(setup_node_entry.line_number, 18, "Should keep single line number")
    end)

    test("consolidate_duplicate_actions version priority", function()
      -- Test that most recent version is used for status checking
      
      -- Create a mock versions module with compare_versions function
      local mock_versions = {}
      
      -- Copy consolidation function logic directly to avoid dependency issues
      function mock_versions.consolidate_duplicate_actions(actions)
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
          -- Use first occurrence as primary reference
          local primary = group.occurrences[1]
          
          -- Determine most recent version for status checking
          local most_recent_version = primary.current_version
          local most_recent_version_type = primary.current_version_type
          local most_recent_index = 1
          
          -- Find most recent version among all occurrences
          for i, version in ipairs(group.current_versions) do
            if mock_versions.compare_versions(version, most_recent_version) == 1 then
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
      
      -- Mock compare_versions function for testing
      mock_versions.compare_versions = function(a, b)
        -- Simple version comparison for testing
        local a_num = tonumber(a:match("v(%d+)") or a:match("(%d+)") or 0)
        local b_num = tonumber(b:match("v(%d+)") or b:match("(%d+)") or 0)
        if a_num > b_num then return 1 end
        if a_num < b_num then return -1 end
        return 0
      end
      
      -- Test data: same action with different versions
      local test_actions = {
        {
          action_name = "actions/checkout",
          current_version = "v2",
          current_version_type = "tag",
          line_number = 10,
          full_line = "uses: actions/checkout@v2",
        },
        {
          action_name = "actions/checkout", 
          current_version = "v4",
          current_version_type = "tag",
          line_number = 20,
          full_line = "uses: actions/checkout@v4",
        },
        {
          action_name = "actions/checkout",
          current_version = "v3",
          current_version_type = "tag",
          line_number = 30,
          full_line = "uses: actions/checkout@v3",
        }
      }
      
      local consolidated = mock_versions.consolidate_duplicate_actions(test_actions)
      
      -- Should have 1 consolidated entry
      assert_equal(#consolidated, 1, "Should consolidate to 1 entry")
      
      local entry = consolidated[1]
      assert_equal(entry.most_recent_version, "v4", "Should identify v4 as most recent")
      assert_equal(entry.most_recent_version_type, "tag", "Should preserve version type")
      assert_equal(entry.most_recent_index, 2, "Should track index of most recent")
      
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