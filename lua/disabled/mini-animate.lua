-- ~/.config/nvim/lua/plugins/mini-animate.lua
-- Type: Plugin
-- Purpose: animate text interactively.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-animate.md
-- Help: :help mini.animate

return {
	"echasnovski/mini.animate",
	version = false,
	event = "VeryLazy",
	config = function()
		require("mini.animate").setup()
	end,
}
