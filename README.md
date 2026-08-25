# Neovim Config

My personal Neovim setup, built on [LazyVim](https://www.lazyvim.org/).

Beyond the LazyVim defaults, this config includes a custom **PeopleCode
development toolchain** for reading and writing PeopleSoft PeopleCode in Neovim —
syntax highlighting, snippets, and a language server providing live diagnostics,
completion, and hover. None of it requires a database connection; it's all built
on the self-hosted parser from [Gideon-Taylor/AppRefiner](https://github.com/Gideon-Taylor/AppRefiner).

The language server and its build instructions live in a separate repo:
**[peoplecode-lazyvim-tools](https://github.com/evanmclean-creator/peoplecode-lazyvim-tools)**.

## PeopleCode tooling

- **Syntax highlighting** — `syntax/`, `ftplugin/`, `ftdetect/` for the
  `peoplecode` filetype (`.pcode` files).
- **Snippets** — `snippets/peoplecode.json`, block skeletons and common patterns
  (if/for/evaluate, function/method/class scaffolds, a full GetSQL fetch loop).
  Auto-discovered by blink.cmp.
- **Language server (pcls)** — configured in `lua/plugins/peoplecode-lsp.lua`.
  Provides diagnostics (syntax errors, missing semicolons, unused/redeclared
  variables, dead code, reused loop iterators), builtin-function completion, and
  hover with full function signatures. This repo only holds the Neovim-side
  config that launches the server; the server source and build steps are in
  [peoplecode-lazyvim-tools](https://github.com/evanmclean-creator/peoplecode-lazyvim-tools).

## Setup notes

- Build and install the pcls server by following the instructions in the
  [peoplecode-lazyvim-tools](https://github.com/evanmclean-creator/peoplecode-lazyvim-tools)
  repo. It installs to `~/.local/share/pcls/`, which is where the `PCLS_DLL` path
  in `peoplecode-lsp.lua` points.
- Requires the .NET 8+ runtime for the language server, plus a local checkout of
  [AppRefiner](https://github.com/Gideon-Taylor/AppRefiner) to build against (the
  tools repo explains this — AppRefiner is referenced, not bundled).

## Restoring on a new machine

Clone this repo into your Neovim config location:
- Windows: `~/AppData/Local/nvim`

Then build and install the pcls server per the
[peoplecode-lazyvim-tools](https://github.com/evanmclean-creator/peoplecode-lazyvim-tools)
README, and LazyVim will bootstrap the remaining plugins on first launch.
