-- SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
--
-- SPDX-License-Identifier: CC0-1.0

return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- Disable tree-sitter in VSCode Neovim extension (VSCode has its own parsers)
    -- Keep it enabled in terminal nvim for better syntax highlighting
    enabled = vim.g.vscode == nil,
    -- Merged with LazyVim's defaults (bash, json, lua, markdown, python, toml,
    -- yaml, ...); list only the parsers a DevSecOps workstation adds.
    opts = {
      ensure_installed = {
        "fish",
        "dockerfile",
        "gitcommit",
        "git_config",
        "git_rebase",
        "gitignore",
        "diff",
        "ssh_config",
        "hcl",
      },
    },
  },
}
