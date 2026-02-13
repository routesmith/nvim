-- ~/.config/nvim/lua/plugins/kanagawa.lua
-- Type: Plugin
-- Purpose: Configures the kanagawa colorscheme with transparency and compiled themes
-- Docs: https://github.com/rebelot/kanagawa.nvim
-- Help: :help kanagawa-usage


return {
    "rebelot/kanagawa.nvim",
    lazy = true, -- only loads when manually triggered
    opts = {
        compile = true,
        transparent = true,
        theme = "dragon", -- "wave", "dragon", or "lotus"
        overrides = function(colors)
            return {
                NormalFloat     = { bg = "NONE" },
                FloatBorder     = { bg = "NONE" },
                Pmenu           = { bg = "NONE" },
                TelescopeNormal = { bg = "NONE" },
                TelescopeBorder = { bg = "NONE" },
            }
        end,
    },
    config = function(_, opts)
        vim.o.background = "dark"
        require("kanagawa").setup(opts)
        -- don't call colorscheme here unless you want this to load by default
    end,
}
