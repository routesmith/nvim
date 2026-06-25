-- ~/.config/nvim/lua/plugins/mini-surround.lua
-- Type: Plugin
-- Purpose: Enables operations for surrounding text (e.g., add/change/delete quotes, brackets).
-- Docs: https://github.com/echasnovski/mini.surround
-- Help: :help mini.surround

return {
	"echasnovski/mini.surround",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.surround").setup({
			mappings = {
				add = "sa", -- Add surrounding
				delete = "sd", -- Delete surrounding
				replace = "sr", -- Replace surrounding
				find = "sf", -- Find right surrounding
				find_left = "sF", -- Find left surrounding
				highlight = "sh", -- Highlight surrounding
				update_n_lines = "sn", -- Update `n_lines`
				suffix_last = "l", -- Suffix to search with "prev" method
				suffix_next = "n", -- Suffix to search with "next" method
			},
		})
	end,
}
