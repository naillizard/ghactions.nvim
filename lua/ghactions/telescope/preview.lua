local M = {}

-- Dependencies
local previewers = require "telescope.previewers"
local conf = require("telescope.config").values
local versions = require "ghactions.github.versions"

-- Version previewer
function M.version_previewer(action_name)
  return previewers.new_buffer_previewer {
    title = "Version Details",
    dyn_title = function(_, entry)
      return "Version Details - " .. (entry.value.version or "Unknown")
    end,

    get_buffer_by_name = function(_, entry)
      return "ghactions_version_preview"
    end,

    define_preview = function(self, entry)
      if not entry or not entry.value then
        return
      end

      local version_entry = entry.value
      local version_info = versions.get_version_info(action_name, version_entry.version)

      if not version_info then
        vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
          "No detailed information available for version " .. version_entry.version,
        })
        vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
        return
      end

      local lines = {}

      -- Header
      table.insert(lines, "Version: " .. version_entry.version)
      table.insert(lines, "Type: " .. version_info.type)
      table.insert(lines, "")

      -- Release information
      if version_info.type == "release" then
        if version_info.name then
          table.insert(lines, "Release Name: " .. version_info.name)
        end

        if version_info.prerelease then
          table.insert(lines, "Pre-release: Yes")
        end

        if version_info.published_at then
          table.insert(lines, "Published: " .. version_info.published_at)
        end

        if version_info.author then
          table.insert(lines, "Author: " .. (version_info.author.login or "Unknown"))
        end

        -- Assets
        if version_info.assets and #version_info.assets > 0 then
          table.insert(lines, "")
          table.insert(lines, "Assets:")
          for _, asset in ipairs(version_info.assets) do
            table.insert(lines, "  - " .. (asset.name or "Unknown") .. " (" .. (asset.size or 0) .. " bytes)")
          end
        end

        -- Release notes
        if version_info.body and version_info.body ~= "" then
          table.insert(lines, "")
          table.insert(lines, "Release Notes:")
          table.insert(lines, "")
          for body_line in version_info.body:gmatch "[^\r\n]+" do
            table.insert(lines, body_line)
          end
        end

      -- Tag information
      elseif version_info.type == "tag" then
        if version_info.commit then
          table.insert(lines, "Commit SHA: " .. version_info.commit.sha)
          table.insert(lines, "Commit URL: " .. version_info.commit.url)
        end

        if version_info.zipball_url then
          table.insert(lines, "Download ZIP: " .. version_info.zipball_url)
        end

        if version_info.tarball_url then
          table.insert(lines, "Download TAR: " .. version_info.tarball_url)
        end
      end

      -- Usage example
      table.insert(lines, "")
      table.insert(lines, "Usage:")
      table.insert(lines, "  uses: " .. action_name .. "@" .. version_entry.version)

      -- Set buffer content
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- Set buffer options
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
    end,
  }
end

-- Current actions previewer for workflow file actions
function M.current_actions_previewer()
  return previewers.new_buffer_previewer {
    title = "Action Details",
    dyn_title = function(_, entry)
      local action_name = entry.value.action_name or "Unknown"
      return "Action Details - " .. action_name
    end,

    get_buffer_by_name = function(_, entry)
      return "ghactions_current_action_preview"
    end,

    define_preview = function(self, entry)
      if not entry or not entry.value then
        return
      end

      local action = entry.value
      local lines = {}

      -- Basic information
      table.insert(lines, "Action: " .. (action.action_name or "Unknown"))
      table.insert(lines, "")

      -- Current version information
      table.insert(lines, "Current Version: " .. (action.current_version or "Unknown"))
      table.insert(lines, "Version Type: " .. (action.current_version_type or "Unknown"))

      if action.latest_version then
        table.insert(lines, "")
        table.insert(lines, "Latest Version: " .. action.latest_version)
        table.insert(lines, "Latest Type: " .. (action.latest_version_type or "Unknown"))
      end

      table.insert(lines, "")
      table.insert(lines, "Status: " .. (action.status or "Unknown"))

      if action.status == "up_to_date" then
        table.insert(lines, "✓ This action is up to date")
        table.insert(lines, "No action needed")
      elseif action.status == "update_available" then
        table.insert(lines, "↑ Update available")
        table.insert(lines, "Consider upgrading to the latest version")
        table.insert(lines, "")
        table.insert(lines, "Actions:")
        table.insert(lines, "  • Press Enter to see available versions")
        table.insert(lines, "  • Press Ctrl+U to update to latest")
        table.insert(lines, "  • Press Ctrl+B in version picker to go back")
      else
        table.insert(lines, "? Status could not be determined")
        table.insert(lines, "Check network connection or action availability")
      end

      table.insert(lines, "")
      table.insert(lines, "File Information:")
      table.insert(lines, "  Line: " .. (action.line_number or "Unknown"))

      if action.full_line then
        table.insert(lines, "  Content: " .. action.full_line)
      end

      -- Set buffer content
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- Set buffer options
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
    end,
  }
end

-- Action previewer for search results
function M.action_previewer()
  return previewers.new_buffer_previewer {
    title = "Action Details",
    dyn_title = function(_, entry)
      local action_name = entry.value.action_name or entry.value.name or "Unknown"
      return "Action Details - " .. action_name
    end,

    get_buffer_by_name = function(_, entry)
      return "ghactions_action_preview"
    end,

    define_preview = function(self, entry)
      if not entry or not entry.value then
        return
      end

      local action = entry.value
      local lines = {}

      -- Handle both current actions picker and search results
      local action_name = action.action_name or action.name or "Unknown"
      local full_name = action.full_name or action_name

      -- Basic information
      table.insert(lines, "Name: " .. action_name)
      table.insert(lines, "Full Name: " .. full_name)

      -- Handle current actions picker data (with update status)
      if action.current_version then
        table.insert(lines, "")
        table.insert(lines, "Current Version: " .. action.current_version)
        table.insert(lines, "Current Type: " .. (action.current_version_type or "Unknown"))

        if action.latest_version then
          table.insert(lines, "Latest Version: " .. action.latest_version)
          table.insert(lines, "Latest Type: " .. (action.latest_version_type or "Unknown"))
        end

        table.insert(lines, "")
        table.insert(lines, "Status: " .. (action.status or "Unknown"))

        if action.status == "up_to_date" then
          table.insert(lines, "✓ This action is up to date")
        elseif action.status == "update_available" then
          table.insert(lines, "↑ Update available - consider upgrading")
        else
          table.insert(lines, "? Status could not be determined")
        end

        table.insert(lines, "")
        table.insert(lines, "File Location: Line " .. (action.line_number or "Unknown"))
      end

      -- Handle search results data (GitHub API info)
      if action.description then
        table.insert(lines, "Description: " .. action.description)
      end

      if action.stargazers_count then
        table.insert(lines, "Stars: " .. action.stargazers_count)
      end

      if action.forks_count then
        table.insert(lines, "Forks: " .. action.forks_count)
      end

      if action.language then
        table.insert(lines, "Language: " .. action.language)
      end

      if action.updated_at then
        table.insert(lines, "Last Updated: " .. action.updated_at)
      end

      -- Topics
      if action.topics and #action.topics > 0 then
        table.insert(lines, "")
        table.insert(lines, "Topics: " .. table.concat(action.topics, ", "))
      end

      -- README preview (if available)
      if action.readme then
        table.insert(lines, "")
        table.insert(lines, "README:")
        table.insert(lines, "")
        -- Truncate README to first 20 lines
        local readme_lines = {}
        for line in action.readme:gmatch "[^\r\n]+" do
          table.insert(readme_lines, line)
          if #readme_lines >= 20 then
            table.insert(readme_lines, "... (truncated)")
            break
          end
        end
        vim.list_extend(lines, readme_lines)
      end

      -- Set buffer content
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- Set buffer options
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
    end,
  }
end

-- Workflow previewer
function M.workflow_previewer()
  return previewers.new_buffer_previewer {
    title = "Workflow Details",
    dyn_title = function(_, entry)
      return "Workflow Details - " .. (entry.value.name or "Unknown")
    end,

    get_buffer_by_name = function(_, entry)
      return "ghactions_workflow_preview"
    end,

    define_preview = function(self, entry)
      if not entry or not entry.value then
        return
      end

      local workflow = entry.value
      local lines = {}

      -- Basic information
      table.insert(lines, "Name: " .. (workflow.name or "Unknown"))
      table.insert(lines, "ID: " .. (workflow.id or "Unknown"))
      table.insert(lines, "Path: " .. (workflow.path or "Unknown"))

      if workflow.state then
        table.insert(lines, "State: " .. workflow.state)
      end

      if workflow.created_at then
        table.insert(lines, "Created: " .. workflow.created_at)
      end

      if workflow.updated_at then
        table.insert(lines, "Updated: " .. workflow.updated_at)
      end

      -- Badge URL
      if workflow.badge_url then
        table.insert(lines, "")
        table.insert(lines, "Badge URL: " .. workflow.badge_url)
      end

      -- HTML URL
      if workflow.html_url then
        table.insert(lines, "HTML URL: " .. workflow.html_url)
      end

      -- Set buffer content
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)

      -- Set buffer options
      vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
      vim.api.nvim_buf_set_option(self.state.bufnr, "modifiable", false)
    end,
  }
end

return M

