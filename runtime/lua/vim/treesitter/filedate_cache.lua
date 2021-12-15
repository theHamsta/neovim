M = {}

local function no_file_changes(stats, old_stats)
  for i, s in ipairs(stats) do
    if s.mtime ~= old_stats[i].mtime then
      return false
    end
  end
  return true
end

function M.make_filedate_cache(file_query_function)
  return setmetatable({}, {
    __index = function(tbl, files)
      local stats = vim.tbl_map(function(f) vim.loop.fs_stat(f) end, files)
      local key = table.concat(files, '\0')
      local cached = rawget(tbl, key)
      if cached and no_file_changes(stats, cached.stats) then
        return cached.result
      else
        local result = file_query_function(files)
        rawset(tbl, key, { result = result, stats = stats })
        return result
      end
    end,
  })
end

return
