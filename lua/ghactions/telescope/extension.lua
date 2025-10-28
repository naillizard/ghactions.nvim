local M = {}

-- Main picker functions
function M.ghactions_picker(opts)
  opts = opts or {}
  local pickers = require "ghactions.telescope.pickers"

  -- Show menu of different picker options
  local pickers_list = {
    { name = "Versions", action = "versions" },
    { name = "Search Actions", action = "search" },
    { name = "Workflows", action = "workflows" },
  }

  require("telescope.pickers")
    .new(opts, {
      prompt_title = "GitHub Actions",
      finder = require("telescope.finders").new_table {
        results = pickers_list,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name,
            ordinal = entry.name,
          }
        end,
      },
      sorter = require("telescope.config").values.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        require("telescope.actions").select_default:replace(function()
          require("telescope.actions").close(prompt_bufnr)
          local selection = require("telescope.actions.state").get_selected_entry()

          if selection.value.action == "versions" then
            pickers.pick_versions(opts)
          elseif selection.value.action == "search" then
            pickers.search_and_pick_actions()
          elseif selection.value.action == "workflows" then
            vim.notify("Workflow picker coming soon!", vim.log.levels.INFO)
          end
        end)

        return true
      end,
    })
    :find()
end

function M.versions_picker(opts)
  opts = opts or {}
  local pickers = require "ghactions.telescope.pickers"
  pickers.pick_versions(opts)
end

function M.search_picker(opts)
  opts = opts or {}
  local pickers = require "ghactions.telescope.pickers"
  pickers.search_and_pick_actions()
end

-- Register extension with Telescope
return require("telescope").register_extension {
  exports = {
    ghactions = M.ghactions_picker,
    ghactions_versions = M.versions_picker,
    ghactions_search = M.search_picker,
  },
}
