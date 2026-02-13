-- ~/.config/nvim/lua/plugins/mini-splitjoin.lua
-- Type: Plugin
-- Purpose: Split and join one-line or multiline constructs for anything
--          Treesitter parses cleanly (node types and structures are recognized,
--          it will try to apply formatting appropriately).
--
--          For instance you can split one-line constructs such as argument
--          lists, tables, arrays, etc into a multiline format, or join them
--          back into a single line.
--
--          Works best in: Lua, Python, JavaScript / TypeScript, Go, Rust,
--          C/C++ (macros can be tricky), Java, Swift, Zig, JSON, YAML, TOML,
--          HTML / XML, CSS.
--
--          Niche support in: Bash/sh, Dockerfile, Vimscript, HCL (Terraform).
--
-- Docs: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-splitjoin.md
-- Help: :help mini.splitjoin

return {
	"echasnovski/mini.splitjoin",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.splitjoin").setup()
	end,
}
