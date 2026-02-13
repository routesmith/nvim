-- ~/.config/nvim/lua/plugins/tokyonight.lua
-- Type: Plugin
-- Purpose: Configures the tokyonight colorscheme with transparency and style
-- Docs: https://github.com/folke/tokyonight.nvim
-- Help: See Docs


return {
    "folke/tokyonight.nvim",
    lazy = true, -- load manually
    opts = {
        style = "moon", -- "storm", "moon", "night", "day"
        transparent = true,
        styles = {
            sidebars = "transparent",
            floats = "transparent",
        },
    },
    config = function(_, opts)
        vim.o.background = "dark"
        require("tokyonight").setup(opts)
        -- do not auto-load the colorscheme
    end,
}
