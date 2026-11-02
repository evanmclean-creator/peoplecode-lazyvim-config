-- ~/AppData/Local/nvim/lua/plugins/peoplecode-lsp.lua  (Windows)
-- ~/.config/nvim/lua/plugins/peoplecode-lsp.lua        (Linux/macOS)
--
-- Starts the pcls PeopleCode language server for .pcode buffers.
-- Provides: live diagnostics, builtin-function/type completion, and hover.
-- No database, no cross-file resolution.
--
-- Prereqs: .NET 8+ runtime, and pcls built + installed (see README).
-- Point PCLS_DLL at your built pcls.dll.

return {
  {
    "neovim/nvim-lspconfig",
    ft = "peoplecode",
    init = function()
      local PCLS_DLL = vim.fn.expand("~/.local/share/pcls/pcls.dll")

      local grp = vim.api.nvim_create_augroup("PcLsp", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = grp,
        pattern = "peoplecode",
        callback = function(args)
          vim.lsp.start({
            name = "pcls",
            cmd = { "dotnet", PCLS_DLL },
            root_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
          }, { bufnr = args.buf })
        end,
      })

      -- Optional: nicer keymaps in PeopleCode buffers
      vim.api.nvim_create_autocmd("LspAttach", {
        group = grp,
        callback = function(ev)
          local c = vim.lsp.get_client_by_id(ev.data.client_id)
          if not c or c.name ~= "pcls" then return end
          local opts = { buffer = ev.buf }
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          -- completion is offered automatically via your completion engine (blink/cmp)
        end,
      })
    end,
  },
}
