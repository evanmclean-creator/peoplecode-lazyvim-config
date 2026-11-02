-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- basedpyright bundles its own Node runtime; plain pyright shells out to a
-- system `node` executable, which isn't on PATH on this machine.
vim.g.lazyvim_python_lsp = "basedpyright"
