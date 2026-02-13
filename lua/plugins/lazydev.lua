-- ~/.config/nvim/lua/plugins/lazydev.lua
-- Type: Plugin
-- Purpose: lazydev.nvim is a plugin that properly configures LuaLS for editing
--          your Neovim config by lazily updating your workspace libraries.
-- Docs: https://github.com/folke/lazydev.nvim
-- Help: :help lazydev.nvim-lazydev.nvim

return {
	"folke/lazydev.nvim",
	ft = "lua", -- only load when editing Lua
	opts = {},
}
