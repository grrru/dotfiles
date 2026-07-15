return {
  PATH = "append",
  ensure_installed = {
    -- LSP
    "ansible-language-server",
    "bash-language-server",
    "basedpyright",
    "docker-compose-language-service",
    "dockerfile-language-server",
    "gopls",
    "json-lsp",
    "lua-language-server",
    "marksman",
    "ruff",
    "vtsls",
    "yaml-language-server",

    -- Formatters
    "gdscript-formatter",
    "goimports",
    "shfmt",
    "stylua",

    -- Linters / tools
    "shellcheck",
  },
}
