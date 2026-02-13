-- ~/.config/nvim/lua/plugins/mini-comment.lua
-- Type: Plugin
-- Purpose: Provides basic and extensible commenting functionality (gcc, gc, etc).
-- Docs: https://github.com/echasnovski/mini.comment
-- Help: :help mini.comment

return {
	"echasnovski/mini.comment",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.comment").setup()
	end,
}
