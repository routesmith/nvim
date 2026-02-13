-- ~/.config/nvim/lua/plugins/nvim-treesitter.lua
-- Type: Plugin
-- Purpose: Sets up Treesitter for better syntax highlighting, folding, and more
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter
-- Help: :help nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		ensure_installed = {
			"bash",
			"c",
			"cpp",
			"diff",
			"html",
			"javascript",
			"json",
			"lua",
			"markdown",
			"markdown_inline",
			"python",
			"regex",
			"toml",
			"vim",
			"yaml",
			"tsx",
			"typescript",
		},
		highlight = {
			enable = true,
			additional_vim_regex_highlighting = false,
		},
		indent = {
			enable = true,
		},
		incremental_selection = {
			enable = true,
			keymaps = {
				init_selection = "<C-n>", -- Start selection (Enter key)
				node_incremental = "<C-n>", -- Expand to next node (Enter again)
				scope_incremental = "<C-f>", -- Expand to the broader scope
				node_decremental = "<C-d>", -- Shrink selection (Backspace)
			},
		},
	},
	config = function(_, opts)
		require("nvim-treesitter.configs").setup(opts)
	end,
}
