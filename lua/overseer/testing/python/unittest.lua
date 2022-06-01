local files = require("overseer.files")
local parser = require("overseer.parser")
local tutils = require("overseer.testing.utils")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local M = {
  name = "python_unittest",
  is_filename_test = function(self, filename)
    return filename:match("^test_.*%.py$")
  end,
  is_workspace_match = function(self, dirname)
    for _, fname in ipairs({ "setup.py", "setup.cfg", "pyproject.toml" }) do
      if files.exists(files.join(dirname, fname)) then
        return true
      end
    end
    return false
  end,
  run_test_dir = function(self, dirname)
    return {
      cmd = { "python", "-m", "unittest", "discover", "-b", "-v", "-s", dirname },
    }
  end,
  run_test_file = function(self, filename)
    return {
      cmd = { "python", "-m", "unittest", "-b", "-v", filename },
    }
  end,
  run_test_in_file = function(self, filename, test)
    return {
      cmd = { "python", "-m", "unittest", "-b", "-v", test.id },
    }
  end,
  get_test_file_from_id = function(self, test_id)
    local pieces = vim.split(test_id, "%.")
    -- Get rid of the test method and test class names
    table.remove(pieces)
    table.remove(pieces)
    return files.join(unpack(pieces)) .. ".py"
  end,
  find_tests = function(self, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local relfile = vim.fn.fnamemodify(filename, ":.:r")
    local path_to_file = vim.split(relfile, files.sep)
    return vim.tbl_map(
      function(item)
        item.fullpath = vim.list_extend(vim.deepcopy(path_to_file), item.path)
        local id = table.concat(item.fullpath, ".")
        if id ~= "" then
          id = id .. "." .. item.name
        else
          id = item.name
        end
        item.id = id
        return item
      end,
      tutils.get_tests_from_ts_query(
        bufnr,
        "python",
        "overseer_python_unittest",
        [[
(class_definition
  name: (identifier) @name (#lua-match? @name "^Test")) @group

(function_definition
  name: (identifier) @name (#lua-match? @name "^test_")) @test
]]
      )
    )
  end,
}

local path_param = {
  "path",
  function(path)
    return vim.split(path, "%.")
  end,
}

local add_id = function(item)
  item.id = table.concat(item.path, ".") .. "." .. item.name
end

M.parser = function()
  return {
    tests = {
      parser.parallel(
        -- Parse successes
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.extract({
              append = false,
              postprocess = function(item)
                add_id(item)
                item.status = TEST_STATUS.SUCCESS
              end,
            }, "^([^%s]+) %((.+)%)$", "name", path_param),
            parser.test(" ok$"),
            parser.append(),
          })
        ),
        -- Parse failures at the end
        parser.loop(
          { ignore_failure = true },
          parser.sequence({
            parser.extract(
              {
                append = false,
                postprocess = add_id,
              },
              "^(FAIL): ([^%s]+) %((.+)%)",
              {
                "status",
                function()
                  return TEST_STATUS.FAILURE
                end,
              },
              "name",
              path_param
            ),
            parser.skip_until("^Traceback"),
            parser.extract_nested(
              "stacktrace",
              parser.loop(parser.sequence({
                parser.extract('%s*File "([^"]+)", line (%d+)', "filename", "lnum"),
                parser.skip_lines(1),
              }))
            ),
          })
        )
      ),
    },
    diagnostics = {
      parser.test("FAIL"),
      parser.skip_until("^Traceback"),
      parser.extract({ append = false }, '%s*File "([^"]+)", line (%d+)', "filename", "lnum"),
      parser.skip_until({ skip_matching_line = false }, "^[^%s]"),
      parser.extract("(.*)", "text"),
    },
  }
end

return M