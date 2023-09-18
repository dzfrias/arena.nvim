local M = {}

--- Truncate paths intelligently. Given { "~/test/mod.rs", "~/test/more/mod.rs" },
--- this function will truncate the paths (in-place) to
--- { "test/mod.rs", "more/mod.rs" }.
--- @param paths string[]
function M.truncate_paths(paths, always_context)
  always_context = always_context or {}

  local components = {}
  for _, path in ipairs(paths) do
    local basename = vim.fs.basename(path)
    components[basename] = (components[basename] or 0) + 1
  end

  for _, basename in ipairs(always_context) do
    components[basename] = (components[basename] or 0) + 1
  end

  for i, path in ipairs(paths) do
    local needed = components[vim.fs.basename(path)]
    local comps = vim.fn.split(path, "/")
    local final_path = ""
    while needed ~= 0 do
      local sep
      if final_path == "" then
        sep = ""
      else
        sep = "/"
      end
      final_path = final_path .. sep .. comps[#comps - needed + 1]
      needed = needed - 1
    end
    paths[i] = final_path
  end
end

return M
