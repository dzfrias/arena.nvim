local frecency = require("arena.frecency")
local util = require("arena.util")

local M = {}

-- Default config
local config = {
  --- Maxiumum items that the arena window can contain.
  max_items = 5,
  --- Always add context to these paths.
  always_context = { "mod.rs", "init.lua" },

  window = {
    width = 60,
    height = 10,
    border = "rounded",
  },

  --- Config for frecency algorithm.
  algorithm = frecency.get_config(),
}

--- @type number?
local bufnr = nil
--- @type number?
local winnr = nil

--- Close the current arena window
local function close()
  vim.api.nvim_win_close(winnr, true)
  winnr = nil
  bufnr = nil
end

function M.toggle()
  -- Close window if it already exists
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    close()
    return
  end

  local items = frecency.top_items(function(name, data)
    return vim.api.nvim_buf_is_loaded(data.buf) and vim.fn.filereadable(name)
  end, config.max_items)
  local buffers = {}
  for _, item in ipairs(items) do
    table.insert(buffers, item.meta.buf)
  end
  local contents = {}
  for _, item in ipairs(items) do
    table.insert(contents, item.name)
  end
  -- Truncate paths, prettier output
  util.truncate_paths(contents, config.always_context)

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

  -- Options
  vim.api.nvim_buf_set_option(bufnr, "filetype", "arena")
  vim.api.nvim_buf_set_name(bufnr, "arena")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "delete")
  vim.api.nvim_buf_set_lines(bufnr, 0, #contents, false, contents)
  vim.api.nvim_buf_set_option(bufnr, "readonly", true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

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
    callback = close,
  })

  local function opener(open_fn)
    return function()
      if #buffers == 0 then
        return
      end
      local idx = vim.fn.line(".")
      local info = vim.fn.getbufinfo(buffers[idx])[1]
      open_fn(buffers[idx])
      vim.fn.cursor(info.lnum, 0)
    end
  end

  -- Keymaps
  vim.keymap.set("n", "q", close, { buffer = bufnr })
  vim.keymap.set(
    "n",
    "<CR>",
    opener(function(buf)
      vim.api.nvim_set_current_buf(buf)
    end),
    { buffer = bufnr }
  )
  vim.keymap.set(
    "n",
    "<C-v>",
    opener(function(buf)
      vim.cmd({
        cmd = "split",
        args = { vim.fn.bufname(buf) },
        mods = { vertical = true },
      })
    end),
    { buffer = bufnr }
  )
  vim.keymap.set(
    "n",
    "<C-x>",
    opener(function(buf)
      vim.cmd({
        cmd = "split",
        args = { vim.fn.bufname(buf) },
        mods = { horizontal = true },
      })
    end),
    { buffer = bufnr }
  )
  vim.keymap.set(
    "n",
    "<C-t>",
    opener(function(buf)
      vim.cmd({
        cmd = "tabnew",
        args = { vim.fn.bufname(buf) },
      })
    end),
    { buffer = bufnr }
  )

  vim.api.nvim_set_current_win(winnr)
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)
  frecency.tune(config.algorithm)
end

local group = vim.api.nvim_create_augroup("arena", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(data)
    if data.file ~= "" and vim.o.buftype == "" then
      frecency.update_item(data.file, { buf = data.buf })
    end
  end,
})

return M
