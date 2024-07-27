local config = require("arena.config")

local M = {
  ---@type integer[]
  pinned = {},
}

---Toggle a pin on a buffer
---@param bufnr integer
function M.pin(bufnr)
  -- Toggle off
  for i, pinned_bufnr in ipairs(M.pinned) do
    if pinned_bufnr == bufnr then
      table.remove(M.pinned, i)
      return
    end
  end

  table.insert(M.pinned, bufnr)
end

---Check if a buffer is pinned
---@param bufnr integer
---@return boolean
function M.is_pinned(bufnr)
  return vim.tbl_contains(M.pinned, bufnr)
end

---Render function for window
---@param item ArenaItem
---@return string
function M.render(item)
  if M.is_pinned(item.bufnr) then
    return item.line .. " " .. config.pin_icon
  end
  return item.line
end

return M
