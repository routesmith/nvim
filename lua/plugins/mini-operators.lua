-- ~/.config/nvim/lua/plugins/mini-operators.lua
-- Type: Plugin
-- Purpose: Add dot-repeatable operators like exchange, multiply, and replace.
-- Docs: https://github.com/echasnovski/mini.operators
-- Help: :help mini.operators

return {
	"echasnovski/mini.operators",
	version = false,
	event = "VeryLazy",
	config = function()
		require("mini.operators").setup()
	end,
}
