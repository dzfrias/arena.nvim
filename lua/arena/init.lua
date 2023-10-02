local frequency = require("arena.frequency")
local util = require("arena.util")

local M = {}

--- @type number?
local bufnr = nil
--- @type number?
local winnr = nil
--- @type number[]?
local buffers = nil

--- Close the current arena window
function M.close()
  vim.api.nvim_win_close(winnr, true)
  winnr = nil
  bufnr = nil
  buffers = nil
end

--- Wrap a function that switches to a buffer in the arena window.
---
--- The function takes in a buffer number, which represents the current buffer
--- that will be switched to. It may also return `false`, to cancel the opening.
---
--- @param fn fun(buf: number, info: table?)
function M.action(fn)
  return function()
    if not buffers or #buffers == 0 then
      return
    end
    local idx = vim.fn.line(".")
    local info = vim.fn.getbufinfo(buffers[idx])[1]
    fn(buffers[idx], info)
  end
end

-- Default config
local config = {
  --- Maxiumum items that the arena window can contain.
  max_items = 5,
  --- Always add context to these paths.
  --- @type string[]
  always_context = { "mod.rs", "init.lua" },
  --- When activated, ignores the current buffer when listing in the arena.
  ignore_current = false,
  --- Options to apply to the arena buffer
  --- @type table<string, any>
  buf_opts = {},

  window = {
    width = 60,
    height = 10,
    border = "rounded",

    --- Options to apply to the arena window
    --- @type table<string, any>
    opts = {},
  },

  --- Keybinds for the arena window.
  --- @type table<string, (function | string)?>
  keybinds = {
    ["<C-x>"] = M.action(function(buf, info)
      vim.cmd({
        cmd = "split",
        args = { vim.fn.bufname(buf) },
        mods = { horizontal = true },
      })
      vim.fn.cursor(info.lnum, 0)
    end),
    ["<C-v>"] = M.action(function(buf, info)
      vim.cmd({
        cmd = "split",
        args = { vim.fn.bufname(buf) },
        mods = { vertical = true },
      })
      vim.fn.cursor(info.lnum, 0)
    end),
    ["<C-t>"] = M.action(function(buf, info)
      vim.cmd({
        cmd = "tabnew",
        args = { vim.fn.bufname(buf) },
      })
      vim.fn.cursor(info.lnum, 0)
    end),
    ["<CR>"] = M.action(function(buf, info)
      vim.api.nvim_set_current_buf(buf)
      vim.fn.cursor(info.lnum, 0)
    end),
    ["q"] = M.close,
  },

  --- Config for frequency algorithm.
  algorithm = frequency.get_config(),
}

function M.open()
  local items = frequency.top_items(function(_, data)
    if config.ignore_current and data.buf == vim.api.nvim_get_current_buf() then
      return false
    end

    if vim.fn.buflisted(data.buf) ~= 1 then
      return false
    end

    return vim.api.nvim_buf_is_loaded(data.buf)
  end, config.max_items)
  buffers = {}
  for _, item in ipairs(items) do
    table.insert(buffers, item.meta.buf)
  end
  local contents = {}
  for _, item in ipairs(items) do
    table.insert(contents, item.name)
  end
  -- Truncate paths, prettier output
  util.truncate_paths(contents, { always_context = config.always_context })

  bufnr = vim.api.nvim_create_buf(false, false)
  winnr = vim.api.nvim_open_win(bufnr, false, {
    relative = "editor",
    row = ((vim.o.lines - config.window.height) / 2) - 1,
    col = (vim.o.columns - config.window.width) / 2,
    width = config.window.width,
    height = config.window.height,
    title = "Arena",
    title_pos = "center",
    border = config.window.border,
  })

  vim.api.nvim_buf_set_lines(bufnr, 0, #contents, false, contents)

  -- Buffer options
  vim.api.nvim_buf_set_option(bufnr, "filetype", "arena")
  vim.api.nvim_buf_set_name(bufnr, "arena")
  vim.api.nvim_buf_set_option(bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  for option, value in pairs(config.buf_opts) do
    vim.api.nvim_buf_set_option(bufnr, option, value)
  end

  -- Window options
  for option, value in pairs(config.window.opts) do
    vim.api.nvim_win_set_option(bufnr, option, value)
  end

  -- Autocommands
  vim.api.nvim_create_autocmd("BufModifiedSet", {
    buffer = bufnr,
    callback = function()
      vim.api.nvim_buf_set_option(bufnr, "modified", false)
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    nested = true,
    once = true,
    callback = M.close,
  })

  -- Keymaps
  for key, fn in pairs(config.keybinds) do
    if not key then
      goto continue
    end
    vim.keymap.set("n", key, fn, { buffer = bufnr })
    ::continue::
  end

  vim.api.nvim_set_current_win(winnr)
end

--- Toggle the arena window
function M.toggle()
  -- Close window if it already exists
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    M.close()
    return
  end
  M.open()
end

--- Set up the config
--- @param opts table?
function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)
  frequency.tune(config.algorithm)
end

local group = vim.api.nvim_create_augroup("arena", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(data)
    if data.file ~= "" and vim.o.buftype == "" then
      frequency.update_item(data.file, { buf = data.buf })
    end
  end,
})

vim.api.nvim_create_user_command("ArenaToggle", M.toggle, {})
vim.api.nvim_create_user_command("ArenaOpen", M.open, {})
vim.api.nvim_create_user_command("ArenaClose", M.close, {})

return M
