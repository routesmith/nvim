-- ~/.config/nvim/lua/config/buffer_reference.lua
-- Purpose: Resolve the current file-backed buffer and render stable references.

local M = {}

local function trim_trailing_separators(path)
	if path:match("^%a:[/\\\\]$") or path == "/" then
		return path
	end
	return (path:gsub("[/\\\\]+$", ""))
end

local function resolve(bufnr)
	if bufnr == 0 or bufnr == nil then
		bufnr = vim.api.nvim_get_current_buf()
	end

	if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
		return nil, "buffer reference requires a valid buffer"
	end

	local buftype = vim.bo[bufnr].buftype
	if buftype ~= "" then
		return nil, ("buffer is not file-backed (buftype=%s)"):format(buftype)
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil, "buffer is unnamed; write it to disk first"
	end

	if name:match("^[%a][%w+.-]*://") then
		return nil, "buffer name is a URI, not a filesystem path"
	end

	local absolute = vim.fn.fnamemodify(name, ":p")
	if absolute == "" then
		return nil, "buffer path could not be resolved"
	end

	return absolute
end

local function home_representation(path)
	local home = trim_trailing_separators(vim.fn.fnamemodify(vim.fn.expand("~"), ":p"))
	if path == home then
		return "~"
	end

	local next_character = path:sub(#home + 1, #home + 1)
	if path:sub(1, #home) == home and (next_character == "/" or next_character == "\\") then
		return "~" .. path:sub(#home + 1)
	end

	return path
end

function M.get(opts)
	opts = opts or {}
	if type(opts) ~= "table" then
		return nil, "buffer reference options must be a table"
	end

	local representation = opts.representation or "absolute"
	if representation ~= "absolute" and representation ~= "home" then
		return nil, ("unknown buffer reference representation: %s"):format(representation)
	end

	local path, err = resolve(opts.bufnr or 0)
	if not path then
		return nil, err
	end

	if representation == "home" then
		return home_representation(path)
	end

	return path
end

return M
