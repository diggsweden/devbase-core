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
