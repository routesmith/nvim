-- ~/.config/nvim/lua/plugins/gruvbox.lua
-- Type: Plugin
-- Purpose: Configures the gruvbox colorscheme with preferred options
-- Docs: https://github.com/ellisonleao/gruvbox.nvim
-- Help: :help gruvbox.txt


--[[
Notes:

    opts = {} vs config = function(_, opts)

This is just a table of options that will be passed into the plugin’s setup()
function automatically if the plugin exposes it. It's purely configuration data
— think of it like:

    require("gruvbox").setup(opts)

"opts" is the ingredients (contrast, transparent_mode, etc), "config" is the cooking.

Don't use config = true, -- Equivalent to: require("plugin").setup()
This is because if a plugin exposes a standard setup() function, lazy.nvim will call:

    require("plugin-name").setup()

on your behalf, when you set:
    config = true -- Equivalent to: require("plugin").setup() 


    config = function(_, opts)
This function is executed after opts = {} is merged with any global/plugin defaults.
This lets you:

1. Set global editor options (like vim.o.background)
2. Call plugin setup() manually if needed
3. Run other initialization logic like applying colorscheme.

    vim.o.background = true -- unrelated to opts; it's just timed to happen before
                            -- the theme loads.

]]
return {
    "ellisonleao/gruvbox.nvim",
    priority = 1000, -- Load first
    lazy = false,    -- Load during startup
    opts = {
        contrast = "hard",
        transparent_mode = true,
        italic = {
            strings = false,
            comments = true,
            operators = false,
            folds = true,
            emphasis = true,
        },
    },
    config = function(_, opts)
        vim.o.background = "dark"
        require("gruvbox").setup(opts)
        vim.cmd.colorscheme("gruvbox")
    end,
}
