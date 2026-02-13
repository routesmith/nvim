-- ~/.config/nvim/lua/plugins/oil.lua
-- Type: Plugin
-- Purpose: File explorer replacement using Oil.nvim with floating window support
-- Docs: https://github.com/stevearc/oil.nvim
-- Help: :help oil.nvim

return {
	"stevearc/oil.nvim",
	---@module 'oil'
	---@type oil.SetupOpts
	opts = {
		keymaps = {
			["q"] = "actions.close",
		},
		view_options = {
			show_hidden = true,
		},
	},
	keys = {
		{ "<leader>o", "<cmd>Oil --float<CR>", desc = "[O]il floating window" },
	},
	dependencies = { { "echasnovski/mini.icons", opts = {} } },
	lazy = false,
	config = function(_, opts)
		require("oil").setup(opts)
	end,
}
