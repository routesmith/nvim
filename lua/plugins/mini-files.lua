-- ~/.config/nvim/lua/plugins/mini-files.lua
-- Type: Plugin
-- Purpose: Minimal file explorer with integrated preview and file actions.
-- Docs: https://github.com/echasnovski/mini.files
-- Help: :help mini.files

return {
	"echasnovski/mini.files",
	version = false,
	keys = {
		{
			"<leader>e",
			function()
				require("mini.files").open()
			end,
			desc = "Open Mini Files Explorer",
		},
	},
	config = function()
		require("mini.files").setup()
	end,
}
