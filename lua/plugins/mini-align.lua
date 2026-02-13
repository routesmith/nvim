-- ~/.config/nvim/lua/plugins/mini-align.lua
-- Type: Plugin
-- Purpose: Align text interactively.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-align.md
-- Help: :help mini.align

return {
	"echasnovski/mini.align",
	version = false,
	event = "VeryLazy",
	config = function()
		require("mini.align").setup()
	end,
}
