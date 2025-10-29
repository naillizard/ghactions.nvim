-- Simple test for consolidation without cache
local function test_consolidation()
  -- Mock the consolidation function directly
  local function consolidate_duplicate_actions(actions)
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

  -- Test data
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
  
  local consolidated = consolidate_duplicate_actions(test_actions)
  
  print("Test Results:")
  print("Original actions:", #test_actions)
  print("Consolidated actions:", #consolidated)
  
  for _, entry in ipairs(consolidated) do
    print(string.format("Action: %s", entry.action_name))
    print(string.format("  Lines: %s", entry.line_numbers_display))
    print(string.format("  Consolidated: %s", tostring(entry.is_consolidated)))
    print(string.format("  Primary line: %d", entry.line_number))
    print("")
  end
end

test_consolidation()