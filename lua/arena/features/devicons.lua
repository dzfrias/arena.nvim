local config = require("arena.config")

local M = {}

local set_cursor = false

local function get_file_extension(path)
  return path:match("^.+%.(%w+)$")
end

---Render function for window
---@param item ArenaItem
---@param win ArenaWindow
---@return RenderData | string
function M.render(item, win)
  local devicons_are_installed, devicons = pcall(require, "nvim-web-devicons")

  if not (config.devicons and devicons_are_installed) then
    return item.line
  end

  local path = vim.fn.getbufinfo(item.bufnr)[1].name
  local icon, iconhl =
    devicons.get_icon(path, get_file_extension(path), { default = true })
  if not icon then
    return item.line
  end

  -- Only set cursor constraint once
  if not set_cursor then
    win:on("CursorMoved", function()
      -- Constrain cursor
      local cur = vim.api.nvim_win_get_cursor(0)
      local min_col = 4
      if cur[2] < min_col then
        vim.api.nvim_win_set_cursor(0, { cur[1], min_col })
      end
      set_cursor = true
    end)
    win:on("BufLeave", function()
      set_cursor = false
    end)
  end

  local icon_line = icon .. " " .. item.line
  return {
    line = icon_line,
    highlight = {
      group = iconhl,
      lnum = item.lnum,
      start_col = 0,
      end_col = #icon,
    },
  }
end

return M
