local frecency = require("arena.frecency")

---@alias Keymap string | fun(win: ArenaWindow)| table

---@class (exact) Highlight
---@field group string
---@field lnum integer
---@field start_col integer
---@field end_col integer

---@class (exact) RenderData
---@field line string
---@field highlight Highlight

---@alias RenderFn fun(item: ArenaItem, win: ArenaWindow):(RenderData | string)

local config = {
  ---Maxiumum items that the arena window can contain.
  ---@type integer
  max_items = 5,
  ---Always add context to these paths.
  ---@type string[]
  always_context = { "mod.rs", "init.lua" },
  ---When activated, ignores the current buffer when listing in the arena.
  ignore_current = false,
  ---Options to apply to the arena buffer
  ---@type table<string, any>
  buf_opts = {},
  ---Filter buffers by project.
  ---@type boolean
  per_project = false,
  ---Add devicons (from nvim-web-devicons, if installed) to buffers
  ---@type boolean
  devicons = true,

  ---Pin icon
  ---@type string
  pin_icon = "●",

  window = {
    ---Window width
    ---@type integer
    width = 60,
    ---Window height
    ---@type integer
    height = 10,
    border = "rounded",

    ---Options to apply to the arena window
    ---@type table<string, any>
    opts = {},
  },

  ---@type RenderFn[]
  renderers = {},

  ---Key mappings for the arena window
  ---@type table<string, Keymap>
  keybinds = {},

  ---Config for frecency algorithm.
  algorithm = frecency.config,
}

return config
