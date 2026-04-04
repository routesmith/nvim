-- ~/.config/nvim/lua/plugins/nvim-treesitter.lua
-- Type: Plugin
-- Purpose: Sets up Treesitter for parser install plus Neovim TS features for
--          better syntax highlighting, folding, and more.
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter
-- Help: :help nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").setup({
			install_dir = vim.fn.stdpath("data") .. "/site",
		})

		require("nvim-treesitter").install({
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
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = {
				"bash",
				"c",
				"cpp",
				"diff",
				"html",
				"javascript",
				"json",
				"lua",
				"markdown",
				"python",
				"toml",
				"vim",
				"yaml",
				"typescript",
				"typescriptreact",
			},
			callback = function(args)
				vim.treesitter.start(args.buf)
				vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
				vim.wo.foldmethod = "expr"
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
