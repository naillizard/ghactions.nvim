if vim.g.loaded_ghactions_nvim then
  return
end
vim.g.loaded_ghactions_nvim = true

local ok, err = pcall(require, "ghactions")
if not ok then
  vim.schedule(function()
    vim.notify("ghactions.nvim: failed to load core module: " .. err, vim.log.levels.ERROR)
  end)
end
