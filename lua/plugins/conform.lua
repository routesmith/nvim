-- ~/.config/nvim/lua/plugins/conform.lua
-- Type: Plugin
-- Purpose: Autoformatting using Conform.nvim with per-language formatter control
-- Docs: https://github.com/stevearc/conform.nvim
-- Help: :help conform.nvim

-- NOTE: Conform only works on syntactically valid code — formatters like `black`, `stylua`, etc.
-- require the code to be parsable to function correctly. If your code contains syntax errors
-- (e.g. unmatched indentations, missing brackets), formatters will fail.

-- For quick fixes to indentation or structural alignment, Neovim's built-in '=' operator is useful
-- (e.g. `gg=G`, `=ap`, or `=G`). These use Neovim’s internal indentation engine, often backed
-- by Treesitter or language-specific `ftplugin` rules. This can correct visual structure
-- but doesn't reformat according to style guides or language conventions.

-- The Language Server (LSP) is your first layer of defense, providing real-time syntax and
-- semantic diagnostics. Use this to fix broken code before invoking Conform.

-- Once syntax is correct, Conform can run formatters on save or via keymaps like <leader>F
-- to ensure consistent code style (e.g. running 'ruff format' on Python files).

-- TIP: Some LSPs also provide their own formatting capabilities, and you may need to disable
-- those if you prefer Conform to handle formatting exclusively.

-- TIP 2: You can use `:ConformInfo` to debug formatter execution and verify that the correct
-- tools are wired up for the current buffer.

return { -- Autoformat
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	cmd = { "ConformInfo" },
	keys = {
		{
			"<leader>F",
			function()
				require("conform").format({ async = true, lsp_format = "fallback" })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = true,
		log_level = vim.log.levels.DEBUG, -- disable when not debugging issues
		format_on_save = function(bufnr)
			-- Disable "format_on_save lsp_fallback" for languages that don't
			-- have a well standardized coding style. You can add additional
			-- languages here or re-enable it for the disabled ones.
			-- local disable_lsp_filetypes = { c = true, cpp = true }
			local disable_lsp_filetypes = {}
			-- Override the default timeout_ms value for specific languages
			local default_timeout = 500
			local timeout_override = { php = 5000 }
			-- Disable formatting on save completely for certain languages
			local disable_filetypes = {}

			local lsp_format_opt
			if disable_lsp_filetypes[vim.bo[bufnr].filetype] then
				lsp_format_opt = "never"
			else
				lsp_format_opt = "fallback"
			end

			local timeout = default_timeout
			if timeout_override[vim.bo[bufnr].filetype] then
				timeout = timeout_override[vim.bo[bufnr].filetype]
			end

			if disable_filetypes[vim.bo[bufnr].filetype] then
				return {
					formatters = {},
					lsp_format = "never",
				}
			else
				return {
					timeout_ms = timeout,
					lsp_format = lsp_format_opt,
				}
			end
		end,
		formatters_by_ft = {
			-- Conform can also run multiple formatters sequentially
			-- python = { "isort", "black" },
			--
			-- You can use 'stop_after_first' to run the first available formatter from the list
			-- javascript = { "prettierd", "prettier", stop_after_first = true },
			lua = { "stylua" },
			python = { "ruff_format" },
			javascript = { "prettierd", "prettier", stop_after_first = true },
			typescript = { "prettierd", "prettier", stop_after_first = true },
			json = { "prettierd", "prettier", stop_after_first = true },
			yaml = { "prettierd" },
			sh = { "shfmt" },
			c = { "clang-format" },
			cpp = { "clang-format" },
		},
		formatters = {
			ruff_format = {
				command = "ruff",
				args = { "format", "--stdin-filename", "$FILENAME", "-" },
				stdin = true,
			},
		},
	},
}
