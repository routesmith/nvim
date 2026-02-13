-- ~/.config/nvim/lua/plugins/mini-indentscope.lua
-- Type: Plugin
-- Purpose: Go forward/backward with square brackets.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-indentscope.md
-- Help: :help mini.indentscope

return {
	"echasnovski/mini.indentscope",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.indentscope").setup()
	end,
}
