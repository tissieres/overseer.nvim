local M = {}

M.STATUS = setmetatable({
  PENDING = "PENDING",
  RUNNING = "RUNNING",
  CANCELED = "CANCELED",
  SUCCESS = "SUCCESS",
  FAILURE = "FAILURE",
}, {
  __index = function(_, key)
    error(string.format("Unknown constant value '%s'", key))
  end,
})

M.CATEGORY = {
  SUMMARY = "SUMMARY",
  RESULT = "RESULT",
  RESULT_HANDLER = "RESULT_HANDLER",
  NOTIFY = "NOTIFY",
  RERUN = "RERUN",
  OTHER = "OTHER",
}

return M
