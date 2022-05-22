local M = {}

local function is_float(value)
  local _, p = math.modf(value)
  return p ~= 0
end

local function calc_float(value, max_value)
  if value and is_float(value) then
    return math.min(max_value, value * max_value)
  else
    return value
  end
end

M.get_editor_width = function()
  return vim.o.columns
end

M.get_editor_height = function()
  return vim.o.lines - vim.o.cmdheight
end

local function calc_list(values, max_value, aggregator, limit)
  local ret = limit
  if type(values) == "table" then
    for _, v in ipairs(values) do
      ret = aggregator(ret, calc_float(v, max_value))
    end
    return ret
  else
    ret = aggregator(ret, calc_float(values, max_value))
  end
  return ret
end

local function calculate_dim(desired_size, exact_size, min_size, max_size, total_size)
  local ret = calc_float(exact_size, total_size)
  local min_val = calc_list(min_size, total_size, math.max, 1)
  local max_val = calc_list(max_size, total_size, math.min, total_size)
  if not ret then
    if not desired_size then
      ret = (min_val + max_val) / 2
    else
      ret = calc_float(desired_size, total_size)
    end
  end
  ret = math.min(ret, max_val)
  ret = math.max(ret, min_val)
  return math.floor(ret)
end

M.calculate_width = function(desired_width, opts)
  return calculate_dim(
    desired_width,
    opts.width,
    opts.min_width,
    opts.max_width,
    M.get_editor_width()
  )
end

M.calculate_height = function(desired_height, opts)
  return calculate_dim(
    desired_height,
    opts.height,
    opts.min_height,
    opts.max_height,
    M.get_editor_height()
  )
end

return M
