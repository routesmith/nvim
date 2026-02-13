-- ~/.config/nvim/lua/plugins/nvim-treesitter-textobjects.lua
-- Type: Plugin
-- Purpose: Enables advanced text object movements and selections using Treesitter
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
-- Help: :help nvim-treesitter-textobjects


return {
    "nvim-treesitter/nvim-treesitter-textobjects",
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("nvim-treesitter.configs").setup({
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        -- 'af' = a function (outer) | use with y/d/v like `yaf` (yank a function)
                        ["af"] = "@function.outer",
                        -- 'if' = inner part of function | e.g. `vif` (select inside function body)
                        ["if"] = "@function.inner",
                        -- 'ac' = a class (outer) | select whole class including signature/decorators
                        ["ac"] = "@class.outer",
                        -- 'ic' = inner class | select class body only
                        ["ic"] = "@class.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start = {
                        -- ]f = jump to start of next function
                        ["]f"] = "@function.outer",
                        -- ]c = jump to start of next class
                        ["]c"] = "@class.outer",
                    },
                    goto_previous_start = {
                        -- [f = jump to start of previous function
                        ["[f"] = "@function.outer",
                        -- [c = jump to start of previous class
                        ["[c"] = "@class.outer",
                    },
                },
                swap = {
                    enable = true,
                    swap_next = {
                        -- <leader>> = swap current parameter with next one
                        ["<leader>>"] = "@parameter.inner",
                    },
                    swap_previous = {
                        -- <leader>< = swap current parameter with previous one
                        ["<leader><"] = "@parameter.inner",
                    },
                },
            },
        })
    end,
}
