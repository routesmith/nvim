-- ~/.config/nvim/lua/plugins/render-markdown.lua
-- Type: Plugin
-- Purpose: Render Markdown in-place without changing the source buffer
-- Docs: https://github.com/MeanderingProgrammer/render-markdown.nvim
-- Help: :help render-markdown

return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
	cmd = { "RenderMarkdown" },
	keys = {
		{
			"<leader>mt",
			function()
				require("render-markdown").toggle()
			end,
			ft = "markdown",
			desc = "[M]arkdown [T]oggle rendering",
		},
		{
			"<leader>mp",
			"<cmd>RenderMarkdown preview<cr>",
			ft = "markdown",
			desc = "[M]arkdown side [P]review",
		},
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"echasnovski/mini.icons",
	},
	opts = {
		render_modes = { "n", "c", "t" },
		max_file_size = 5.0,
		latex = { enabled = false },
		completions = {
			blink = { enabled = false },
			lsp = { enabled = false },
		},
	},
}
