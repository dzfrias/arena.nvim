local M = {}

--- @type table<string, { count: number, last_used: number, meta: table }>
local usages = {}

--- Update an item for the frecency algorithm.
--- @param item string
--- @param meta table
function M.update_item(item, meta)
  meta = meta or {}
  local current_time = os.time()
  if usages[item] == nil then
    -- If the item is used for the first time, initialize its data
    usages[item] = { count = 1, last_used = current_time, meta = meta }
  else
    -- If the item has been used before, update its data
    local data = usages[item]
    data.count = data.count + 1
    data.last_used = current_time
  end
end

--- Get the frecency score of an item.
--- @param item string
--- @return number
function M.calc_frecency(item)
  local data = usages[item]
  if data == nil then
    -- Not been used before, return 0
    return 0
  end

  local RECENCY_DAMPEN = 0.2
  local recency_factor = 1 / (os.time() - data.last_used + 1)
  local frequency_factor = data.count
  recency_factor = recency_factor * (1 - RECENCY_DAMPEN)

  local frecency = recency_factor * frequency_factor

  return frecency
end

--- Get the most frecent items, in descending order.
--- @param filter (fun(name: string, data: table): boolean)?
--- @return table<{ name: string, score: number, meta: table }>
function M.top_items(filter)
  local frecencies = {}
  local i = 1
  for name, data in pairs(usages) do
    if filter and not filter(name, data.meta) then
      goto continue
    end
    local score = M.calc_frecency(name)
    frecencies[i] = { name = name, score = score, meta = data.meta }
    i = i + 1
    ::continue::
  end
  table.sort(frecencies, function(a, b)
    return a.score > b.score
  end)
  return frecencies
end

return M
