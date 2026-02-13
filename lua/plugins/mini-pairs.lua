-- ~/.config/nvim/lua/plugins/mini-pairs.lua
-- Type: Plugin
-- Purpose: Minimal and fast autopairs.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-pairs.md
-- Help: :help mini.pairs

return {
	"echasnovski/mini.pairs",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.pairs").setup()
	end,
}
