-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Alt + scroll wheel scrolls sideways
-- (Windows Terminal strips the Shift modifier off wheel events before they
-- reach the app, and Ctrl+wheel is already claimed by WT for font zoom, so
-- Alt is the only modifier that actually survives to Neovim.)
local scroll_opts = { silent = true }
local hscroll_cols = 12

-- Note: zh/zl drag the cursor along as they scroll, so scrolling clamps to
-- the current line's length rather than the window's actual content width.
vim.keymap.set({ "n", "v" }, "<M-ScrollWheelUp>", hscroll_cols .. "zh", scroll_opts)
vim.keymap.set({ "n", "v" }, "<M-ScrollWheelDown>", hscroll_cols .. "zl", scroll_opts)
-- Some terminals/GUIs send these directly instead
vim.keymap.set({ "n", "v" }, "<ScrollWheelLeft>", hscroll_cols .. "zh", scroll_opts)
vim.keymap.set({ "n", "v" }, "<ScrollWheelRight>", hscroll_cols .. "zl", scroll_opts)
