local frecency = require("arena.frecency")
local util = require("arena.util")
local config = require("arena.config")
local Window = require("arena.window")
local pin = require("arena.features.pin")
local devicons = require("arena.features.devicons")

local M = {}

---Main arena window
M.window = Window.new()

local function split(win, opts)
  local current = win:current()
  local info = vim.fn.getbufinfo(current.bufnr)[1]
  vim.cmd({
    cmd = "split",
    args = { vim.fn.bufname(current.bufnr) },
    mods = opts,
  })
  vim.fn.cursor(info.lnum, 0)
end

local DEFAULT_KEYMAPS = {
  ["<C-x>"] = function(win)
    split(win, { horizontal = true })
  end,
  ["<C-v>"] = function(win)
    split(win, { vertical = true })
  end,
  ["<C-t>"] = function(win)
    local current = win:current()
    local info = vim.fn.getbufinfo(current.bufnr)[1]
    vim.cmd({
      cmd = "tabnew",
      args = { vim.fn.bufname(current.bufnr) },
    })
    vim.fn.cursor(info.lnum, 0)
  end,
  ["<CR>"] = function(win)
    local current = win:current()
    local info = vim.fn.getbufinfo(current.bufnr)[1]
    vim.api.nvim_set_current_buf(current.bufnr)
    vim.fn.cursor(info.lnum, 0)
  end,
  ["p"] = function(win)
    local current = win:current()
    pin.pin(current.bufnr)
    M.refresh()
  end,
  ["d"] = {
    function(win)
      local current = win:current()
      M.remove(current.bufnr)
    end,
    { nowait = true },
  },
  ["D"] = function(win)
    for _, bufnr in pairs(win.buffers) do
      M.remove(bufnr)
    end
  end,
  ["q"] = function(win)
    win:close()
  end,
  ["<esc>"] = function(win)
    win:close()
  end,
}

local RENDER_LIST = {
  pin.render,
  devicons.render,
}

M.window.keymaps =
  vim.tbl_deep_extend("force", DEFAULT_KEYMAPS, config.keybinds)

M.window.renderers = { unpack(config.renderers) }
for _, renderer in pairs(RENDER_LIST) do
  table.insert(M.window.renderers, renderer)
end

---Close the current arena window
function M.close()
  M.window:close()
end

---Open the arena window
function M.open()
  -- Get the most frecent buffers
  local items = frecency.top_items(function(name, data)
    local parent = vim.api.nvim_get_current_buf()
    if M.window:is_mounted() then
      parent = M.window.parent_bufnr
    end
    if config.ignore_current and data.buf == parent then
      return false
    end

    if config.per_project then
      local current = vim.api.nvim_buf_get_name(0)
      local root_dir
      for dir in vim.fs.parents(current) do
        if vim.fn.isdirectory(vim.fs.joinpath(dir, ".git")) == 1 then
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

    return true
  end, config.max_items)

  local buffers = {}
  for _, buf in ipairs(pin.pinned) do
    table.insert(buffers, buf)
  end
  for _, item in ipairs(items) do
    if not pin.is_pinned(item.meta.buf) then
      table.insert(buffers, item.meta.buf)
    end
  end
  if #buffers > config.max_items then
    for _ = 0, #buffers - config.max_items do
      table.remove(buffers)
    end
  end
  M.window:mount(buffers)
end

---Toggle the arena window
function M.toggle()
  -- Close window if it already exists
  if M.window:is_mounted() then
    M.close()
    return
  end
  M.open()
end

---Remove an entry from the window.
---@param bufnr integer
function M.remove(bufnr)
  if not M.window:contains(bufnr) then
    error("cannot remove buffer that isn't in the arena window")
    return
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  frecency.remove_item(name)
  vim.api.nvim_buf_delete(bufnr, {})
  M.refresh()
end

---Refresh the arena window
function M.refresh()
  if not M.window:is_mounted() then
    error("trying to refresh arena when nothing is mounted")
    return
  end
  M.open()
end

---Check if a buffer is pinned.
---@param bufnr integer
function M.is_pinned(bufnr)
  return pin.is_pinned(bufnr)
end

---Toggle a pin on an entry in the window.
---@param bufnr integer
function M.pin(bufnr)
  if M.window:contains(bufnr) then
    error("cannot pin buffer that hasn't been opened yet")
    return
  end
  pin.pin(bufnr)
  M.refresh()
end

--- Set up the config.
--- @param opts table?
function M.setup(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    if type(v) == "table" and type(config[k]) == "table" then
      config[k] = vim.tbl_deep_extend("force", config[k], v)
    else
      config[k] = v
    end
  end
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

vim.api.nvim_create_user_command("ArenaToggle", M.toggle, {})
vim.api.nvim_create_user_command("ArenaOpen", M.open, {})
vim.api.nvim_create_user_command("ArenaClose", M.close, {})

---Get the corresponding arena usages file from a filepath
---@param session_file string
---@return string
local function arena_file(session_file)
  local basename = vim.fs.basename(session_file)
  local dirname = vim.fs.dirname(session_file)
  return vim.fs.joinpath(
    dirname,
    -- Strip the .vim, add _arena.json
    basename:sub(0, #basename - 4) .. "_arena.json"
  )
end

local function save_session()
  local session_file = vim.api.nvim_get_vvar("this_session")
  if session_file == "" then
    return
  end
  local usages = vim.json.encode(frecency.usages)
  util.write_file(arena_file(session_file), usages)
end

vim.api.nvim_create_autocmd("User", {
  pattern = "PersistenceSavePost",
  group = group,
  callback = save_session,
})

vim.api.nvim_create_autocmd("SessionWritePost", {
  group = group,
  callback = save_session,
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
    frecency.usages = data
  end,
})

return M
