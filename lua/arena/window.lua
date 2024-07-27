local config = require("arena.config")
local utils = require("arena.util")

---@class (exact) ArenaItem
---@field bufnr integer
---@field line string
---@field lnum integer

---@class ArenaWindow
---@field bufnr integer
---@field winnr integer
---@field parent_bufnr integer
---@field buffers integer[]
---@field renderers RenderFn[]
---@field keymaps table<string, Keymap>
local M = {}
M.__index = M

local BUF_OPTS = {
  filetype = "arena",
  readonly = true,
  bufhidden = "delete",
  buftype = "nofile",
  modifiable = false,
}

---@return ArenaWindow
function M.new()
  return setmetatable({}, M)
end

---@param bufs integer[]
function M:mount(bufs)
  if self:is_mounted() then
    self:close()
  else
    self.parent_bufnr = vim.api.nvim_get_current_buf()
  end

  self.bufnr = vim.api.nvim_create_buf(false, false)
  self.winnr = vim.api.nvim_open_win(self.bufnr, false, {
    relative = "editor",
    row = ((vim.o.lines - config.window.height) / 2) - 1,
    col = (vim.o.columns - config.window.width) / 2,
    width = config.window.width,
    height = config.window.height,
    title = "Arena",
    title_pos = "center",
    border = config.window.border,
  })
  self.buffers = {}

  local lines = {}
  for _, bufnr in pairs(bufs) do
    local name = vim.fn.getbufinfo(bufnr)[1].name
    table.insert(lines, name)
    table.insert(self.buffers, bufnr)
  end

  utils.truncate_paths(lines, { always_context = config.always_context })

  local to_highlight = {}
  for i, line in ipairs(lines) do
    local bufnr = self.buffers[i]
    local new_line = line
    for _, renderer in pairs(self.renderers) do
      local render =
        renderer({ bufnr = bufnr, line = new_line, lnum = i - 1 }, self)
      if type(render) == "string" then
        new_line = render
      else
        new_line = render.line
        table.insert(to_highlight, render.highlight)
      end
    end
    lines[i] = new_line
  end

  -- Set contents of buffer
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)

  -- Highlight after setting lines
  for _, highlight in pairs(to_highlight) do
    vim.api.nvim_buf_add_highlight(
      self.bufnr,
      self:namespace(),
      highlight.group,
      highlight.lnum,
      highlight.start_col,
      highlight.end_col
    )
  end

  -- Buffer options
  for option, value in
    pairs(vim.tbl_deep_extend("keep", BUF_OPTS, config.buf_opts))
  do
    vim.api.nvim_buf_set_option(self.bufnr, option, value)
  end

  -- Window options
  for option, value in pairs(config.window.opts) do
    vim.api.nvim_win_set_option(self.winnr, option, value)
  end

  for key, mapping in pairs(self.keymaps) do
    local fn
    local opts = { buffer = self.bufnr }
    if type(mapping) == "table" then
      fn = mapping[1]
      opts = vim.tbl_extend("force", mapping[2], { buffer = self.bufnr })
    else
      fn = mapping
    end
    -- Could be a string
    if type(fn) == "function" then
      local user_keymap = fn
      fn = function()
        user_keymap(self)
      end
    end
    vim.keymap.set("n", key, fn, opts)
  end

  -- Autocommands
  self:on("BufLeave", function()
    self:close()
  end)

  pcall(vim.api.nvim_set_current_win, self.winnr)
end

---Get the augroup for the window
---@param clear boolean?
---@return integer
function M:augroup(clear)
  return vim.api.nvim_create_augroup("arena_window", { clear = clear == true })
end

---Get the namespace of the window
---@return integer
function M:namespace()
  return vim.api.nvim_create_namespace("arena_window_highlight")
end

---Check if the window is open or not
---@return boolean
function M:is_mounted()
  ---@diagnostic disable return-type-mismatch
  return self.winnr
    and vim.api.nvim_win_is_valid(self.winnr)
    and self.bufnr
    and vim.api.nvim_buf_is_valid(self.bufnr)
    and vim.api.nvim_win_get_buf(self.winnr) == self.bufnr
end

---Close the window
function M:close()
  pcall(vim.api.nvim_win_close, self.winnr, true)
  self:augroup(true)
  self.winnr = nil
  self.bufnr = nil
  self.buffers = {}
end

---Get the current arena item
---@return ArenaItem
function M:current()
  local index = vim.api.nvim_win_get_cursor(self.winnr)[1]
  return self:get(index)
end

---Get the nth arena item
---@param n integer
---@return ArenaItem
function M:get(n)
  local bufnr = self.buffers[n]
  return {
    bufnr = bufnr,
    line = vim.api.nvim_get_current_line(),
    lnum = n - 1,
  }
end

---Check if the arena contains a given buffer
---@param bufnr integer
---@return boolean
function M:contains(bufnr)
  return vim.tbl_contains(self.buffers, bufnr)
end

---Set an autocommand
---@param event string
---@param fn fun(self: ArenaWindow, event: { buf: integer }):boolean?
---@param opts? vim.api.keyset.create_autocmd
function M:on(event, fn, opts)
  opts = opts or {}
  opts.buffer = self.bufnr
  opts.callback = function(e)
    return fn(self, e)
  end
  opts.group = self:augroup()
  vim.api.nvim_create_autocmd(event, opts)
end

return M
