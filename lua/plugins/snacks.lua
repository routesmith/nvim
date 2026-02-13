-- ~/.config/nvim/lua/plugins/snacks.lua
-- Type: Plugin
-- Purpose: A collection of quality of life plugins for Neovim.
--          A couple of plugins require snacks.nvim to be setup early. Setup
--          creates some autocmds and does not load any plugins.  Check the
--          code to see what it does.
--
--          You need to explicitly pass options for a plugin or set
--          "enabled = true" to enable it.
--
--          It's a good idea to run :checkhealth snacks to see if everything is
--          setup correctly.
--
-- Docs: https://github.com/folke/snacks.nvim
-- Help: :help snacks.nvim.txt

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		input = { enabled = true },
		picker = { enabled = true },
	},
}
