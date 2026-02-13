-- ~/.config/nvim/init.lua
-- Type: Config
-- Purpose: Neovim entry point; sets leader keys, loads core configuration, and bootstraps plugin manager
-- Docs: https://github.com/folke/lazy.nvim

-- Set leader keys early
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load core configuration
require("config.options")
require("config.keymaps")
require("config.autocommands")

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf })
    for _, client in ipairs(clients) do
      if type(client.name) ~= "string" then
        vim.notify(
          "Malformed LSP client detected at BufWritePre: " .. vim.inspect(client),
          vim.log.levels.ERROR
        )
      end
    end
  end,
})

-- Setup plugin manager
require("config.lazy")
