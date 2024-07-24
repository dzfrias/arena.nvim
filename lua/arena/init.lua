local frecency = require("arena.frecency")
local util = require("arena.util")

local M = {}

--- @type number?
local bufnr = nil
--- @type number?
local parent_bufnr = nil
--- @type number?
local winnr = nil
--- @type number[]?
local buffers = nil
--- @type table<number, string>
local bufnames = {}
--- @type number[]
local pinned = {}

--- Close the current arena window
function M.close()
  vim.api.nvim_win_close(winnr, true)
  winnr = nil
  bufnr = nil
  buffers = nil
end

--- Wrap a function that does something to the buffer the cursor is over.
---
--- The function should take in a buffer number, which represents the current
--- buffer that the cursor is over.
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

--- Wrap a function that is applied to each buffer in the window.
---
--- The function should take in a buffer number, which represents the current
--- buffer that the cursor is over.
---
--- @param fn fun(buf: number, info: table?)
function M.action_all(fn)
  return function()
    for _, buf in ipairs(buffers or {}) do
      local info = vim.fn.getbufinfo(buf)[1]
      fn(buf, info)
    end
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
  --- When set to a string, will highlight the current buffer.
  --- @type string | boolean
  highlight_current = false,
  --- Options to apply to the arena buffer
  --- @type table<string, any>
  buf_opts = {},
  --- Filter buffers by project.
  --- @type boolean
  per_project = false,
  --- Add devicons (from nvim-web-devicons, if installed) to buffers
  --- @type boolean
  devicons = false,

  window = {
    width = 60,
    height = 10,
    border = "rounded",

    --- Options to apply to the arena window
    --- @type table<string, any>
    opts = {},
  },

  --- Keybinds for the arena window.
  --- @type table<string, (function | string | table)?>
  keybinds = {
    ["<C-x>"] = {
      M.action(function(buf, info)
        vim.cmd({
          cmd = "split",
          args = { vim.fn.bufname(buf) },
          mods = { horizontal = true },
        })
        vim.fn.cursor(info.lnum, 0)
      end),
      {},
    },
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
    ["d"] = {
      M.action(function(buf)
        M.remove(buf)
      end),
      {
        nowait = true,
      },
    },
    ["D"] = M.action_all(function(buf)
      if M.is_pinned(buf) then
        return
      end
      M.remove(buf)
    end),
    ["p"] = M.action(function(buf)
      M.pin(buf)
    end),
    ["q"] = M.close,
    ["<esc>"] = M.close,
  },

  --- Config for frecency algorithm.
  algorithm = frecency.get_config(),
}

function M.open()
  -- Get the most frecent buffers
  local items = frecency.top_items(function(name, data)
    local parent = vim.api.nvim_get_current_buf()
    if winnr ~= nil then
      parent = parent_bufnr
    end
    if config.ignore_current and data.buf == parent then
      return false
    end

    if config.per_project then
      local current = vim.api.nvim_buf_get_name(0)
      local root_dir
      for dir in vim.fs.parents(current) do
        if vim.fn.isdirectory(dir .. "/.git") == 1 then
          root_dir = dir
          break
        end
      end
      if not root_dir then
        return true
      end
      if not vim.startswith(name, root_dir) then
        return false
      end
    end

    if vim.fn.buflisted(data.buf) ~= 1 then
      return false
    end

    return data.session or vim.api.nvim_buf_is_loaded(data.buf)
  end, config.max_items)

  buffers = {}
  local contents = {}
  for _, buf in ipairs(pinned) do
    local name = vim.fn.getbufinfo(buf)[1].name
    table.insert(buffers, buf)
    table.insert(contents, name)
  end
  for _, item in ipairs(items) do
    if vim.tbl_contains(pinned, item.meta.buf) then
      goto continue
    end
    table.insert(buffers, item.meta.buf)
    table.insert(contents, item.name)
    ::continue::
  end
  if #contents > config.max_items then
    for _ = 0, #contents - config.max_items do
      table.remove(contents)
    end
  end
  if #buffers > config.max_items then
    for _ = 0, #buffers - config.max_items do
      table.remove(buffers)
    end
  end
  -- Truncate paths, prettier output
  util.truncate_paths(contents, { always_context = config.always_context })

  local devicons_are_installed, devicons = pcall(require, "nvim-web-devicons")
  local devicon_highlights = {}
  if config.devicons and devicons_are_installed then
    local function get_file_extension(file_path)
      return file_path:match("^.+%.(%w+)$")
    end

    for i, item in ipairs(contents) do
      local icon = devicons.get_icon_color(
        item,
        get_file_extension(item),
        { default = true }
      )
      local _, iconhl =
        devicons.get_icon(item, get_file_extension(item), { default = true })

      if icon then
        devicon_highlights[i] = {
          iconhl = iconhl,
          icon = icon,
        }
        contents[i] = icon .. " " .. item
      end
    end
  end

  if #pinned > 0 then
    for i, item in ipairs(contents) do
      if pinned[i] then
        if config.devicons then
          contents[i] = item .. " ●"
        else
          contents[i] = "● " .. item
        end
      end
    end
  end

  local function highlight_devicons()
    if not (config.devicons and devicons_are_installed) then
      return
    end
    for i, highlight in ipairs(devicon_highlights) do
      vim.api.nvim_buf_add_highlight(
        bufnr,
        vim.api.nvim_create_namespace("arena"),
        highlight.iconhl,
        i - 1,
        0,
        #highlight.icon
      )
    end
  end

  if winnr ~= nil then
    vim.api.nvim_buf_set_option(bufnr, "readonly", false)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
    vim.api.nvim_buf_set_option(bufnr, "readonly", true)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    highlight_devicons()
    return
  end

  parent_bufnr = vim.api.nvim_get_current_buf()
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

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)

  highlight_devicons()

  if config.highlight_current then
    if type(config.highlight_current) == "boolean" then
      config.highlight_current = "comment"
    end
    for i, item in ipairs(contents) do
      if parent_bufnr ~= buffers[i] then
        goto continue
      end
      vim.api.nvim_buf_add_highlight(
        bufnr,
        vim.api.nvim_create_namespace("arena"),
        config.highlight_current,
        i - 1,
        0,
        #item
      )
      ::continue::
    end
  end

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
    vim.api.nvim_win_set_option(winnr, option, value)
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
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = bufnr,
    callback = function()
      if not config.devicons then
        return
      end
      -- Constrain cursor
      local cur = vim.api.nvim_win_get_cursor(0)
      local min_col = 4
      if cur[2] < min_col then
        vim.api.nvim_win_set_cursor(0, { cur[1], min_col })
      end
    end,
  })

  -- Keymaps
  for key, fn in pairs(config.keybinds) do
    if not key then
      goto continue
    end
    if type(fn) == "table" then
      local merged = vim.tbl_extend("force", fn[2], { buffer = bufnr })
      vim.keymap.set("n", key, fn[1], merged)
    else
      vim.keymap.set("n", key, fn, { buffer = bufnr })
    end
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

--- Remove an entry from the window.
--- @param buf number The buffer id of the buffer to remove.
function M.remove(buf)
  if not bufnames[buf] then
    error("cannot remove buffer that hasn't been opened yet")
    return
  end

  frecency.remove_item(bufnames[buf])
  vim.api.nvim_buf_delete(buf, {})
  M.refresh()
end

function M.refresh()
  if winnr ~= nil then
    M.open()
  end
end

--- Check if a buffer has been pinned.
--- @param buf number The buffer id of the buffer to check
function M.is_pinned(buf)
  return vim.tbl_contains(pinned, buf)
end

--- Toggle a pin on an entry in the window.
--- @param buf number The buffer id of the buffer to pin.
function M.pin(buf)
  if not bufnames[buf] then
    error("cannot pin buffer that hasn't been opened yet")
    return
  end

  for i, pinned_buf in ipairs(pinned) do
    if pinned_buf == buf then
      table.remove(pinned, i)
      M.refresh()
      return
    end
  end

  table.insert(pinned, buf)
  M.refresh()
end

--- Set up the config.
--- @param opts table?
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
      bufnames[data.buf] = data.file
    end
  end,
})

vim.api.nvim_create_user_command("ArenaToggle", M.toggle, {})
vim.api.nvim_create_user_command("ArenaOpen", M.open, {})
vim.api.nvim_create_user_command("ArenaClose", M.close, {})

--- Get the corresponding arena usages file from a filepath
--- @param session_file string
--- @return string
local function arena_file(session_file)
  local basename = vim.fs.basename(session_file)
  local dirname = vim.fs.dirname(session_file)
  return vim.fs.joinpath(
    dirname,
    basename:sub(0, #basename - 4) .. "_arena.json"
  )
end

vim.api.nvim_create_autocmd("SessionWritePost", {
  group = group,
  callback = function()
    local session_file = vim.api.nvim_get_vvar("this_session")
    if session_file == "" then
      return
    end
    local usages = vim.json.encode(frecency.raw_usages())
    util.write_file(arena_file(session_file), usages)
  end,
})

vim.api.nvim_create_autocmd("SessionLoadPost", {
  group = group,
  callback = function()
    local session_file = vim.api.nvim_get_vvar("this_session")
    local contents = util.read_file(arena_file(session_file))
    if contents == nil then
      return
    end
    local json_data = vim.json.decode(contents)
    local data = {}
    for file, usage in pairs(json_data) do
      local buf = vim.fn.bufnr(file)
      if buf ~= -1 then
        usage.meta.session = true
        usage.meta.buf = buf
        data[file] = usage
      end
    end
    frecency.set_raw_usages(data)
  end,
})

return M
