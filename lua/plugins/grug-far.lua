-- ~/.config/nvim/lua/plugins/grug-far.lua
-- Type: Plugin
-- Purpose: Opinionated find-and-replace (FAR) plugin built for speed and batch edits.
--          "Replace using almost the full power of rg or ast-grep."
-- Docs: https://github.com/MagicDuck/grug-far.nvim
-- Help: :help grug-far

return {
	"MagicDuck/grug-far.nvim",
	-- Note (lazy loading): grug-far.lua defers all it's requires so it's lazy by default
	-- additional lazy config to defer loading is not really needed...
	config = function()
		-- optional setup call to override plugin options
		-- alternatively you can set options with vim.g.grug_far = { ... }
		require("grug-far").setup({
			-- options, see Configuration section below
			-- there are no required options atm
		})
	end,
}
