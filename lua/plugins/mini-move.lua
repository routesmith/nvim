-- ~/.config/nvim/lua/plugins/mini-move.lua
-- Type: Plugin
-- Purpose: Enables moving lines, selections, and blocks up/down/left/right.
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-move.md
-- Help: :help mini.move

return {
	"echasnovski/mini.move",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.move").setup({
			mappings = {
				left = "<M-h>",
				right = "<M-l>",
				down = "<M-j>",
				up = "<M-k>",

				line_left = "<M-h>",
				line_right = "<M-l>",
				line_down = "<M-j>",
				line_up = "<M-k>",
			},
		})
	end,
}
