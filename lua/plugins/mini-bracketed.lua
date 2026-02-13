-- ~/.config/nvim/lua/plugins/mini-bracketed.lua
-- Type: Plugin
-- Purpose: Go forward/backward with square brackets.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-bracketed.md
-- Help: :help mini.bracketed

return {
	"echasnovski/mini.bracketed",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.bracketed").setup()
	end,
}
