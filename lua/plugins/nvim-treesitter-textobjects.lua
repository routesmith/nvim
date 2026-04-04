-- ~/.config/nvim/lua/plugins/nvim-treesitter-textobjects.lua
-- Type: Plugin
-- Purpose: Enables advanced text object movements and selections using Treesitter
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
-- Help: :help nvim-treesitter-textobjects

-- ~/.config/nvim/lua/plugins/nvim-treesitter-textobjects.lua
-- Type: Plugin
-- Purpose: Enables advanced text object movements and selections using Treesitter
-- Docs: nvim-treesitter-textobjects

return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	branch = "main",
	lazy = false,
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("nvim-treesitter-textobjects").setup({
			select = {
				lookahead = true,
			},
			move = {
				set_jumps = true,
			},
		})

		vim.keymap.set({ "x", "o" }, "af", function()
			require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
		end)

		vim.keymap.set({ "x", "o" }, "if", function()
			require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects")
		end)

		vim.keymap.set({ "x", "o" }, "ac", function()
			require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects")
		end)

		vim.keymap.set({ "x", "o" }, "ic", function()
			require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects")
		end)

		vim.keymap.set({ "n", "x", "o" }, "]f", function()
			require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
		end)

		vim.keymap.set({ "n", "x", "o" }, "]c", function()
			require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects")
		end)

		vim.keymap.set({ "n", "x", "o" }, "[f", function()
			require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
		end)

		vim.keymap.set({ "n", "x", "o" }, "[c", function()
			require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects")
		end)

		vim.keymap.set("n", "<leader>>", function()
			require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
		end)

		vim.keymap.set("n", "<leader><", function()
			require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
		end)
	end,
}
