local M = {}

-- Flag to prevent double execution of back navigation
local back_executing = false

-- Dependencies
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local entry_display = require "telescope.pickers.entry_display"

-- Local modules
local versions = require "ghactions.github.versions"
local config = require "ghactions.config"

-- Create display columns for version picker
local function create_displayer()
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 20 }, -- Version
      { width = 10 }, -- Type
      { width = 12 }, -- Date
      { width = 9 }, -- SHA (short)
      { remaining = true }, -- Description
    },
  }

  return displayer
end

-- Create entry for version picker
local function create_entry(version_entry)
  local displayer = create_displayer()

  local version = version_entry.version
  local type_info = version_entry.type or ""
  local date = version_entry.published_at or ""
  local description = ""
  local short_sha = ""

  -- Extract short SHA from commit data
  if version_entry.commit and version_entry.commit.sha then
    short_sha = string.sub(version_entry.commit.sha, 1, 8)
  end

  if version_entry.info then
    if version_entry.info.name then
      description = version_entry.info.name
    elseif version_entry.info.body then
      description = version_entry.info.body:sub(1, 50)
      if #version_entry.info.body > 50 then
        description = description .. "..."
      end
    end
  end

  -- Format date
  if date and date ~= "" then
    -- Parse ISO date string and format it
    local year, month, day = date:match "^(%d+)-(%d+)-(%d+)"
    if year and month and day then
      date = string.format("%s-%s-%s", year, month, day)
    else
      date = date -- Keep original if parsing fails
    end
  end

  -- Add prerelease indicator
  if version_entry.prerelease then
    type_info = type_info .. " [pre]"
  end

  return {
    value = version_entry,
    display = function(entry)
      return displayer {
        { version, "TelescopeResultsIdentifier" },
        { type_info, "TelescopeResultsComment" },
        { date, "TelescopeResultsSpecialComment" },
        { short_sha, "TelescopeResultsNumber" },
        { description, "TelescopeResultsFunction" },
      }
    end,
    ordinal = version .. " " .. type_info .. " " .. short_sha .. " " .. description,
  }
end

-- Version picker implementation
local function version_picker(opts)
  opts = opts or {}

  -- Get telescope configuration
  local telescope_config = config.get("telescope", {})

  -- Get action name from options or prompt
  local action_name = opts.action_name
  if not action_name then
    action_name = vim.fn.input "Action name (owner/repo): "
    if action_name == "" then
      vim.notify("Action name is required", vim.log.levels.ERROR)
      return
    end
  end

  -- Show loading message
  vim.notify("Fetching versions for " .. action_name .. "...", vim.log.levels.INFO)

  -- Get versions
  local versions_list, err = versions.get_sorted_versions(action_name)
  if err then
    vim.notify("Failed to fetch versions: " .. err, vim.log.levels.ERROR)
    return
  end

  if #versions_list == 0 then
    vim.notify("No versions found for " .. action_name, vim.log.levels.WARN)
    return
  end

  -- Create picker with custom layout (preview on right, list on left)
  pickers
    .new(opts, {
      prompt_title = "GitHub Actions Versions - " .. action_name .. " (Ctrl+B to go back)",
      finder = finders.new_table {
        results = versions_list,
        entry_maker = create_entry,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            opts.on_select(selection.value)
          end
        end)

        -- Add custom mappings
        map("i", "<C-r>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            opts.on_refresh(selection.value)
          end
        end)

        map("i", "<C-p>", function()
          local selection = action_state.get_selected_entry()
          if selection then
            opts.on_pin(selection.value)
          end
        end)

        -- Add back mapping if on_back callback is provided
        if opts.on_back then
          map("i", "<C-b>", function()
            if not back_executing then
              back_executing = true
              actions.close(prompt_bufnr)
              vim.schedule(function()
                M.pick_current_actions()
                back_executing = false
              end, 10)
            end
          end)

          map("n", "<C-b>", function()
            if not back_executing then
              back_executing = true
              actions.close(prompt_bufnr)
              vim.schedule(function()
                M.pick_current_actions()
                back_executing = false
              end, 10)
            end
          end)

          map("n", "b", function()
            if not back_executing then
              back_executing = true
              actions.close(prompt_bufnr)
              vim.schedule(function()
                M.pick_current_actions()
                back_executing = false
              end, 10)
            end
          end)
        end

        return true
      end,
      previewer = require("ghactions.telescope.preview").version_previewer(action_name),
      layout_strategy = telescope_config.layout_strategy or "horizontal",
      layout_config = telescope_config.layout_config or {
        horizontal = {
          preview_width = 0.4, -- Preview takes 60% of width
          results_width = 0.6, -- List takes 40% of width
        },
      },
    })
    :find()
end

-- Main function to open version picker
function M.pick_versions(opts)
  opts = opts or {}

  -- Merge with telescope configuration
  local telescope_config = config.get("telescope", {})
  opts = vim.tbl_deep_extend("force", telescope_config, opts)

  version_picker(opts)
end

-- Quick version picker for current buffer
function M.pick_current_action_versions()
  -- Try to extract action name from current buffer
  local line = vim.fn.line "."
  local content = vim.fn.getline(line)

  -- Look for action pattern
  local action_match = content:match "uses%s*=%s*[\"']([^\"']+)[\"']"
  if action_match then
    local action_name = versions.parse_action_name(action_match)
    if action_name then
      M.pick_versions {
        action_name = action_name,
        on_select = function(version_entry)
          -- Get the correct version based on type: release->SHA, tag->tag name
          local new_version, is_sha = versions.get_version_for_update(version_entry)
          local new_action = action_name .. "@" .. new_version
          local new_line = content:gsub("uses%s*=%s*[\"'][^\"']+[\"']", 'uses = "' .. new_action .. '"')
          vim.fn.setline(line, new_line)
          vim.notify("Updated to " .. new_action, vim.log.levels.INFO)
        end,
      }
      return
    end
  end

  -- Fallback to manual input
  M.pick_versions()
end

-- Search and pick actions
function M.search_and_pick_actions()
  local query = vim.fn.input "Search actions: "
  if query == "" then
    return
  end

  -- Parse the action name to ensure it's in the correct format
  local action_name = versions.parse_action_name(query)
  if not action_name then
    vim.notify("Invalid action name format. Use: owner/repo", vim.log.levels.ERROR)
    return
  end

  -- Open version picker with proper selection logic
  M.pick_versions {
    action_name = action_name,
    prompt_title = "GitHub Actions Versions - " .. action_name .. " (Ctrl+B to go back)",
    on_select = function(version_entry)
      -- Get the current line and cursor position
      local line = vim.fn.line "."
      local col = vim.fn.col "."
      local current_line_content = vim.fn.getline(line)

      -- Get the correct version based on type: release->SHA, tag->tag name
      local new_version, is_sha = versions.get_version_for_update(version_entry)
      local new_action = action_name .. "@" .. new_version

      -- Try to replace an existing action at cursor position, or insert new one
      local new_line

      -- Check if there's an action at the current position
      local action_match = current_line_content:match "uses%s*=%s*[\"']([^\"']+)[\"']"
      if action_match then
        -- Replace existing action
        new_line = current_line_content:gsub("uses%s*=%s*[\"'][^\"']+[\"']", 'uses = "' .. new_action .. '"')
      else
        -- Insert new action at cursor position
        local before_cursor = current_line_content:sub(1, col - 1)
        local after_cursor = current_line_content:sub(col)
        new_line = before_cursor .. 'uses = "' .. new_action .. '"' .. after_cursor
      end

      vim.fn.setline(line, new_line)
      vim.notify("Updated to " .. new_action, vim.log.levels.INFO)
    end,
  }
end

-- Create display columns for current actions picker
local function create_current_actions_displayer()
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 25 }, -- Action name
      { width = 12 }, -- Current version
      { width = 12 }, -- Latest version
      { width = 16 }, -- Status
      { remaining = true }, -- File info
    },
  }

  return displayer
end

-- Update action in file (reusable function)
local function update_action_in_file(selection, version_entry)
  -- Get the correct version based on type: release->SHA, tag->tag name
  local new_version, is_sha = versions.get_version_for_update(version_entry)
  local new_action = selection.action_name .. "@" .. new_version

  -- Determine which lines to update
  local lines_to_update
  if selection.is_consolidated and selection.line_numbers then
    -- Update all instances of this action
    lines_to_update = selection.line_numbers
  else
    -- Update just this single line
    lines_to_update = { selection.line_number }
  end

  -- Update each line
  for _, line_num in ipairs(lines_to_update) do
    local current_line = vim.fn.getline(line_num)

    -- Replace the action in YAML format, preserving quote style if present
    local new_line
    if current_line:match "uses:%s*[\"']" then
      -- With quotes
      local quote_char = current_line:match "uses:%s*([\"'])"
      new_line =
        current_line:gsub("uses:%s*[\"'][^\"'%s]+[\"']?", "uses: " .. quote_char .. new_action .. quote_char)
    else
      -- Without quotes
      new_line = current_line:gsub("uses:%s*[^\"'%s]+", "uses: " .. new_action)
    end

    -- Add comment with tag name if we're using SHA and original was a tag
    -- Only add comment if this specific line didn't already have one
    if is_sha and not current_line:match("#.*v%d") then
      local comment = " # " .. version_entry.version
      new_line = new_line:gsub("%s*$", "") .. comment
    end

    vim.fn.setline(line_num, new_line)
  end
  vim.notify("Updated " .. selection.action_name .. " to " .. new_version, vim.log.levels.INFO)
end

-- Create entry for current actions picker
local function create_current_actions_entry(action_entry)
  local displayer = create_current_actions_displayer()

  -- Truncate versions if too long
  local current_version = action_entry.current_version
  local latest_version = action_entry.latest_version or "Unknown"

  if #current_version > 10 then
    current_version = current_version:sub(1, 10) .. ".."
  end
  if #latest_version > 10 then
    latest_version = latest_version:sub(1, 10) .. ".."
  end

  -- Status display with icon and color
  local status_display = ""
  local status_highlight = ""

  if action_entry.status == "up_to_date" then
    status_display = "✓ Up to date"
    status_highlight = "TelescopeResultsComment"
  elseif action_entry.status == "update_available" then
    status_display = "↑ Update available"
    status_highlight = "TelescopeResultsWarning"
  else
    status_display = "? Unknown"
    status_highlight = "TelescopeResultsError"
  end

  -- File info - show all line numbers if consolidated
  local file_info
  if action_entry.is_consolidated and action_entry.line_numbers_display then
    file_info = "Lines " .. action_entry.line_numbers_display
  else
    file_info = "Line " .. action_entry.line_number
  end

  return {
    value = action_entry,
    display = function(entry)
      return displayer {
        { action_entry.action_name, "TelescopeResultsIdentifier" },
        { current_version, "TelescopeResultsNumber" },
        { latest_version, "TelescopeResultsSpecialComment" },
        { status_display, status_highlight },
        { file_info, "TelescopeResultsFunction" },
      }
    end,
    ordinal = action_entry.action_name .. " " .. current_version .. " " .. latest_version .. " " .. action_entry.status,
  }
end

-- Current actions picker implementation
local function current_actions_picker(opts)
  opts = opts or {}

  -- Get telescope configuration
  local telescope_config = config.get("telescope", {})

  -- Find actions in current buffer
  local current_actions = versions.find_actions_in_buffer()
  if not current_actions or #current_actions == 0 then
    vim.notify("No GitHub Actions found in current file", vim.log.levels.WARN)
    return
  end

  -- Consolidate duplicate actions before enriching
  current_actions = versions.consolidate_duplicate_actions(current_actions)
  
  -- Enrich actions with update status
  current_actions = versions.enrich_actions_with_status(current_actions)

  -- Create picker
  local picker = pickers.new(opts, {
    prompt_title = "GitHub Actions in Current File",
    finder = finders.new_table {
      results = current_actions,
      entry_maker = create_current_actions_entry,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Show version picker for the selected action
          M.pick_versions {
            action_name = selection.value.action_name,
            on_select = function(version_entry)
              update_action_in_file(selection.value, version_entry)
            end,
            on_back = function()
              -- Close current version picker and go back to actions list
              actions.close(prompt_bufnr)
              vim.schedule(function()
                M.pick_current_actions()
              end)
            end,
          }
        end
      end)

      -- Add custom mapping for quick update to latest
      map("i", "<C-u>", function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value.status == "update_available" then
          local latest_version = selection.value.latest_version
          if latest_version then
            -- Create a proper version entry for the latest version
            local latest_version_entry = {
              version = latest_version,
              type = selection.value.latest_version_type, -- "release" or "tag"
            }

            -- Get commit information based on type
            if selection.value.latest_version_type == "release" then
              -- For releases, get the commit SHA from the tags
              local versions_data = versions.get_action_versions(selection.value.action_name)
              if versions_data then
                -- Find the corresponding tag for this release
                for _, tag in ipairs(versions_data.tags) do
                  if tag.name == latest_version and tag.commit then
                    latest_version_entry.commit = tag.commit
                    break
                  end
                end
              end
            elseif selection.value.latest_version_type == "tag" then
              -- For tags, also get the commit info (but we'll use tag name for updates)
              local version_info = versions.get_version_info(selection.value.action_name, latest_version)
              if version_info and version_info.commit then
                latest_version_entry.commit = version_info.commit
              end
            end

            -- Update using reusable function and refresh picker
            update_action_in_file(selection.value, latest_version_entry)

            -- Refresh the picker data to reflect the update
            local refreshed_actions = versions.find_actions_in_buffer()
            if refreshed_actions and #refreshed_actions > 0 then
              refreshed_actions = versions.consolidate_duplicate_actions(refreshed_actions)
              refreshed_actions = versions.enrich_actions_with_status(refreshed_actions)

              -- Update the finder with refreshed data
              local finder = require("telescope.finders").new_table {
                results = refreshed_actions,
                entry_maker = create_current_actions_entry,
              }

              -- Get the current picker and update its finder
              local picker = action_state.get_current_picker(prompt_bufnr)
              picker:refresh(finder, { reset_prompt = false })
            end
          else
            vim.notify("Could not get latest version for " .. selection.value.action_name, vim.log.levels.ERROR)
          end
        else
          vim.notify(
            "No update available for " .. (selection and selection.value.action_name or "selected action"),
            vim.log.levels.WARN
          )
        end
      end)

      -- Add normal mode mapping for quick update to latest
      map("n", "<C-u>", function()
        local selection = action_state.get_selected_entry()
        if selection and selection.value.status == "update_available" then
          local latest_version = selection.value.latest_version
          if latest_version then
            -- Create a proper version entry for the latest version
            local latest_version_entry = {
              version = latest_version,
              type = selection.value.latest_version_type, -- "release" or "tag"
            }

            -- Get commit information based on type
            if selection.value.latest_version_type == "release" then
              -- For releases, get the commit SHA from the tags
              local versions_data = versions.get_action_versions(selection.value.action_name)
              if versions_data then
                -- Find the corresponding tag for this release
                for _, tag in ipairs(versions_data.tags) do
                  if tag.name == latest_version and tag.commit then
                    latest_version_entry.commit = tag.commit
                    break
                  end
                end
              end
            elseif selection.value.latest_version_type == "tag" then
              -- For tags, also get the commit info (but we'll use tag name for updates)
              local version_info = versions.get_version_info(selection.value.action_name, latest_version)
              if version_info and version_info.commit then
                latest_version_entry.commit = version_info.commit
              end
            end

            -- Update using reusable function and refresh picker
            update_action_in_file(selection.value, latest_version_entry)

            -- Refresh the picker data to reflect the update
            local refreshed_actions = versions.find_actions_in_buffer()
            if refreshed_actions and #refreshed_actions > 0 then
              refreshed_actions = versions.consolidate_duplicate_actions(refreshed_actions)
              refreshed_actions = versions.enrich_actions_with_status(refreshed_actions)

              -- Update the finder with refreshed data
              local finder = require("telescope.finders").new_table {
                results = refreshed_actions,
                entry_maker = create_current_actions_entry,
              }

              -- Get the current picker and update its finder
              local picker = action_state.get_current_picker(prompt_bufnr)
              picker:refresh(finder, { reset_prompt = false })
            end
          else
            vim.notify("Could not get latest version for " .. selection.value.action_name, vim.log.levels.ERROR)
          end
        else
          vim.notify(
            "No update available for " .. (selection and selection.value.action_name or "selected action"),
            vim.log.levels.WARN
          )
        end
      end)

      return true
    end,
    previewer = require("ghactions.telescope.preview").current_actions_previewer(),
    layout_strategy = telescope_config.layout_strategy or "horizontal",
    layout_config = telescope_config.layout_config or {
      horizontal = {
        preview_width = 0.6,
        results_width = 0.4,
      },
    },
  })

  picker:find()
end

-- Main function to open current actions picker
function M.pick_current_actions(opts)
  opts = opts or {}

  -- Merge with telescope configuration
  local telescope_config = config.get("telescope") or {}
  opts = vim.tbl_deep_extend("force", telescope_config, opts or {})

  current_actions_picker(opts)
end

return M
