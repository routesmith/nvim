-- ~/.config/nvim/lua/plugins/forge-projection.lua
-- Type: Local integration
-- Purpose: Bind the read-only Forge projection to this host and fzf-lua.

local function forge_root()
	if vim.env.FORGE_ROOT and vim.env.FORGE_ROOT ~= "" then
		return vim.env.FORGE_ROOT
	end

	local local_path = vim.fn.stdpath("config") .. "/lua/config/forge_projection.local.lua"
	if vim.fn.filereadable(local_path) == 0 then
		return nil
	end
	local ok, local_config = pcall(dofile, local_path)
	if not ok then
		error("failed to load Forge projection local config: " .. tostring(local_config), 0)
	end
	local root = type(local_config) == "table" and local_config.root or local_config
	if type(root) ~= "string" or root == "" then
		error("Forge projection local config must return a root string or { root = ... }", 0)
	end
	return root
end

return {
	"ibhagwan/fzf-lua",
	init = function()
		require("config.forge_projection").setup({ root = forge_root() })
	end,
	keys = {
		{
			"<leader>fo",
			function()
				require("config.forge_projection").overview()
			end,
			desc = "[f]orge current-work [o]verview",
		},
		{
			"<leader>fF",
			function()
				require("config.forge_projection").find()
			end,
			desc = "[f]ind whole [F]orge corpus",
		},
	},
}
