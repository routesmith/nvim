-- ~/.config/nvim/lua/config/zoxide_nav.lua
-- Purpose: FZF-Lua-powered Zoxide integration for mini.files and oil.nvim.
--          Supports cross-platform preview fallback between Unix and PowerShell.
-- Requires: fzf-lua, zoxide, optionally bat, ls/head, or PowerShell

local M = {}

-- Extract path from zoxide query line
local function parse_zoxide_path(line)
	if line then
		return line:match("^%s*[%d%.]+%s+(.*)")
	end
	return nil
end

-- Platform-aware directory preview logic
local function preview_dir(dir)
	if not dir or vim.fn.isdirectory(dir) ~= 1 then
		return { "Not a valid directory or no directory selected." }
	end

	local sysname = vim.loop.os_uname().sysname
	local command

	if sysname == "Windows_NT" then
		if vim.fn.executable("ls") == 1 and vim.fn.executable("head") == 1 then
			command = "ls -F " .. vim.fn.fnameescape(dir) .. " | head -200"
		else
			-- Use PowerShell fallback
			return vim.fn.systemlist({
				"powershell",
				"-NoProfile",
				"-Command",
				"Get-ChildItem -Force -Name -LiteralPath '" .. dir .. "'",
			})
		end
	else
		command = "ls -F " .. vim.fn.fnameescape(dir) .. " | head -200"
	end

	local handle = io.popen(command)
	if handle then
		local output = handle:read("*a")
		handle:close()
		return vim.split(output, "\n", { plain = true, trimempty = true })
	else
		return { "Error: Could not list directory contents for preview." }
	end
end

-- FZF-Lua Zoxide picker with platform-aware preview
local function zoxide_fzf_picker(open_callback)
	local fzf = require("fzf-lua")

	fzf.fzf_exec("zoxide query -ls", {
		prompt = "Zoxide> ",
		preview = {
			fn = function(lines)
				local selected_line = lines[1]
				local dir = parse_zoxide_path(selected_line)
				return preview_dir(dir)
			end,
			layout = "right",
			width = "50%",
			wrap = false,
		},
		actions = {
			["default"] = function(selected)
				local dir = parse_zoxide_path(selected[1])
				if dir and vim.fn.isdirectory(dir) == 1 then
					open_callback(dir)
				else
					vim.notify("Invalid or no directory selected", vim.log.levels.WARN)
				end
			end,
		},
	})
end

function M.setup()
	-- Zoxide → mini.files
	vim.keymap.set("n", "<leader>ze", function()
		zoxide_fzf_picker(function(dir)
			if pcall(require, "mini.files") then
				require("mini.files").open(dir)
			else
				vim.notify("mini.files not loaded", vim.log.levels.WARN)
			end
		end)
	end, { desc = "Zoxide: Open in mini.files" })

	-- Zoxide → Oil (float)
	vim.keymap.set("n", "<leader>zo", function()
		zoxide_fzf_picker(function(dir)
			if pcall(require, "oil") then
				vim.cmd("Oil --float " .. vim.fn.fnameescape(dir))
			else
				vim.notify("oil.nvim not loaded", vim.log.levels.WARN)
			end
		end)
	end, { desc = "Zoxide: Open in oil.nvim (float)" })
end

return M
