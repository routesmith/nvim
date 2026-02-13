-- ~/.config/nvim/lua/config/autocommands.lua
-- Type: Config
-- Purpose: Defines general-purpose autocommands
-- Docs: https://neovim.io/doc/user/autocmd.html
-- Help: :help lua-guide-autocommands, :help autocmd

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- If in WSL, use cmd.exe to start the browser so that you don't get a non-zero
-- return value from explorer.exe.
if vim.fn.has("wsl") == 1 then
	vim.ui.open = function(uri)
		vim.fn.jobstart({ "/mnt/c/Windows/System32/cmd.exe", "/C", "start", uri }, { detach = true })
	end
end

if vim.fn.has("macunix") == 1 then
	vim.ui.open = function(uri)
		local firefox = "/Applications/Firefox.app"
		if vim.fn.isdirectory(firefox) == 1 then
			vim.fn.jobstart({ "open", "-a", "Firefox", uri }, { detach = true })
		else
			vim.fn.jobstart({ "open", uri }, { detach = true })
		end
	end
end
