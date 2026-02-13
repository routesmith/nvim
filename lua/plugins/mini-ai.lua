-- ~/.config/nvim/lua/plugins/mini-ai.lua
-- Type: Plugin
-- Purpose: Provides enhanced text objects (e.g., a(, i", a<CR>) with Treesitter support.
-- Docs: https://github.com/echasnovski/mini.ai
-- Help: :help mini.ai

return {
	"echasnovski/mini.ai",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.ai").setup()
	end,
}
