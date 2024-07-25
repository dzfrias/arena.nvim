local M = {}

--- @type table<string, { count: number, last_used: number, meta: table }>
M.usages = {}
-- Default config values
local config = {
  --- Multiply the recency by a factor. Must be greater than zero.
  recency_factor = 0.5,
  --- Multiply the frequency by a factor. Must be greater than zero.
  frequency_factor = 1,
}

--- Get the current frecency config.
--- @return table
function M.get_config()
  return config
end

--- Configure the frecency algorithm.
--- @param opts table
function M.tune(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)

  if config.recency_factor < 0 then
    config.recency_factor = 0
    error("recency_factor cannot be less than 0!")
  end

  if config.frequency_factor < 0 then
    config.frequency_factor = 0
    error("frequency_factor cannot be less than 0!")
  end
end

--- Update an item for the frecency algorithm.
--- @param item string
--- @param meta table
function M.update_item(item, meta)
  meta = meta or {}
  local current_time = os.time()
  if M.usages[item] == nil then
    -- If the item is used for the first time, initialize its data
    M.usages[item] = { count = 1, last_used = current_time, meta = meta }
  else
    -- If the item has been used before, update its data
    local data = M.usages[item]
    data.count = data.count + 1
    data.last_used = current_time
  end
end

--- Get the frecency score of an item.
--- @param item string
--- @return number
function M.calc_frecency(item)
  local data = M.usages[item]
  if data == nil then
    -- Not been used before, return 0
    return 0
  end

  local recency_factor = 1 / (os.time() - data.last_used + 1)
  local frequency_factor = data.count * config.frequency_factor
  recency_factor = recency_factor * config.recency_factor

  local frecency = recency_factor * frequency_factor

  return frecency
end

--- Get the most frecent items, in descending order.
--- @param filter (fun(name: string, data: table): boolean)?
--- @param n number?
--- @return table<{ name: string, score: number, meta: table }>
function M.top_items(filter, n)
  local frecencies = {}
  local i = 1
  for name, data in pairs(M.usages) do
    if filter and not filter(name, data.meta) then
      goto continue
    end
    local score = M.calc_frecency(name)
    table.insert(frecencies, { name = name, score = score, meta = data.meta })
    i = i + 1
    ::continue::
  end
  table.sort(frecencies, function(a, b)
    return a.score > b.score
  end)

  if n then
    local new = {}
    for j = 1, n do
      new[j] = frecencies[j]
    end
    return new
  end

  return frecencies
end

--- Remove an item from the frecency store.
--- @param item string
function M.remove_item(item)
  M.usages[item] = nil
end

return M
