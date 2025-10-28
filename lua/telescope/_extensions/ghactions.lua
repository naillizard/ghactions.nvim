-- Telescope extension for ghactions.nvim
-- This file registers the extension with Telescope

local extension = require "ghactions.telescope.extension"

return require("telescope").register_extension {
  exports = {
    ghactions = extension.ghactions_picker,
    ghactions_versions = extension.versions_picker,
    -- ghactions_search = extension.search_picker,
  },
}
