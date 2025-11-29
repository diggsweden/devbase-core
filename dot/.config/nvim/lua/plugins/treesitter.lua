-- SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
--
-- SPDX-License-Identifier: CC0-1.0

return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Disable tree-sitter in VSCode Neovim extension (VSCode has its own parsers)
    -- Keep it enabled in terminal nvim for better syntax highlighting
    enabled = vim.g.vscode == nil,
    opts = {
      auto_install = true,
      ensure_installed = {
        "bash",
        "fish",
        "lua",
        "yaml",
        "json",
        "toml",
        "markdown",
        "markdown_inline",
        "python",
        "vim",
        "vimdoc",
        "regex",
      },
    },
  },
}
