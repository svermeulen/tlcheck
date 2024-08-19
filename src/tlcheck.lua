local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
local tl = require("tl")

if #arg ~= 1 then
   print("Teal Check\nUsage: teal-check [PATH]\nNote:\n - Given path can be a single .tl file or a directory (which will be searched recursively for all .tl files)\n - A tlconfig.lua file must be present in the given directory or a parent of the given directory/path\n - This program is designed to be more script/machine friendly than human friendly.  The output is easy to parse but not easy to read.  Using teal version '" .. tl.version() .. "'")
   os.exit(1)
end

local lfs = require("lfs")











local function ivalues(t)
   local i = 0
   return function()
      i = i + 1
      return t[i]
   end
end

local function try_get_parent_path(path)
   return path:match('(.*[/\\]).+')
end

local function path_is_absolute(path)
   return path:sub(1, 1) == "/" or path:match('^[a-zA-Z]:[\\/]') ~= nil
end

local function path_has_trailing_slash(path)
   local last_char = path:sub(#path)
   return last_char == "/" or last_char == "\\"
end

local function remove_trailing_slash_if_exists(path)
   if path_has_trailing_slash(path) then
      return path:sub(1, #path - 1)
   end
   return path
end

local function try_get_path_type(path)

   path = remove_trailing_slash_if_exists(path)

   local path_type = lfs.attributes(path, "mode")
   if path_type ~= "directory" and path_type ~= "file" then
      path_type = nil
   end
   return path_type
end

local function get_sub_paths(path)
   assert(try_get_path_type(path) == "directory")

   local result = {}

   for sub_path in lfs.dir(path) do


      if sub_path:sub(1, 1) ~= "." then
         table.insert(result, sub_path)
      end
   end

   return result
end

local function path_join(left, right)
   if path_has_trailing_slash(left) then
      return left .. right
   end

   return string.format("%s/%s", left, right)
end

local function try_find_tlconfig_path(start_search_path)
   assert(#start_search_path > 0, "Invalid path given")
   assert(path_is_absolute(start_search_path))

   local path_type = try_get_path_type(start_search_path)

   if path_type == nil then
      error(string.format("Invalid path given '%s'", start_search_path))
   end

   local search_dir

   if path_type == "directory" then
      search_dir = start_search_path
   else
      assert(path_type == "file")
      search_dir = try_get_parent_path(start_search_path)
   end

   while search_dir ~= nil do
      for _, sub_path in ipairs(get_sub_paths(search_dir)) do
         local full_path = path_join(search_dir, sub_path)
         if sub_path == "tlconfig.lua" and try_get_path_type(full_path) == "file" then
            return full_path
         end
      end

      search_dir = try_get_parent_path(search_dir)
   end

   return nil
end

local function process_include_dir_arg(include_dir, tlconfig_path)
   if include_dir == nil then
      return {}
   end

   local all_dirs = {}


   if type(include_dir) == "string" then
      table.insert(all_dirs, include_dir)
   else
      all_dirs = include_dir
   end

   local adjusted_dirs = {}
   local tlconfig_dir = try_get_parent_path(tlconfig_path)

   for _, dir in ipairs(all_dirs) do
      assert(#dir > 0, "Invalid value given for include_dir")

      if dir == "." then
         table.insert(adjusted_dirs, tlconfig_dir)
      else
         if not path_is_absolute(dir) then
            dir = tlconfig_dir .. dir
         end

         if not path_has_trailing_slash(dir) then
            dir = dir .. "/"
         end

         table.insert(adjusted_dirs, dir)
      end
   end

   return adjusted_dirs
end

local function process_global_env_def_arg(global_env_def)

   if type(global_env_def) == "string" then
      return { global_env_def }
   end
   return global_env_def
end






local function add_result(results, result)
   if result.warnings then
      for _, err in ipairs(result.warnings) do
         table.insert(results.warnings, err)
      end
   end

   if result.syntax_errors then
      for _, err in ipairs(result.syntax_errors) do
         table.insert(results.errors, err)
      end
   end

   if result.type_errors then
      for _, err in ipairs(result.type_errors) do
         table.insert(results.errors, err)
      end
   end
end

local function run_teal_check_on_file(path, env, all_results)
   local result, process_error = tl.process(path, env)

   if process_error ~= nil then
      error("Error while processing file '" .. path .. "': " .. process_error)
   end

   add_result(all_results, result)
end

local function get_all_tl_files_in_directory_recursive(start_path)
   assert(try_get_path_type(start_path) == "directory")

   local queue = { start_path }
   local result = {}

   while #queue > 0 do
      local search_dir = queue[#queue]
      table.remove(queue, #queue)

      for _, path in ipairs(get_sub_paths(search_dir)) do
         local full_path = path_join(search_dir, path)
         local path_mode = try_get_path_type(full_path)

         if path_mode == "directory" then
            table.insert(queue, full_path)
         elseif path_mode == "file" and path:sub(-3) == ".tl" then
            table.insert(result, full_path)
         end
      end
   end

   return result
end

local function run_teal_check(tlconfig_path, path, global_modules)
   local path_file_type = try_get_path_type(path)


   local env, env_error = tl.init_env(
   false, nil, nil, global_modules)

   if env == nil then
      return {
         errors = {
            {
               y = 0,
               x = 0,
               filename = tlconfig_path,
               msg = "Failed to initialize teal environment:  " .. env_error,
            },
         },
         warnings = {},
      }
   end

   local results = {
      errors = {},
      warnings = {},
   }

   if path_file_type == "file" then
      run_teal_check_on_file(path, env, results)
   else
      assert(path_file_type == "directory", "Invalid path given")

      local all_tl_files = get_all_tl_files_in_directory_recursive(path)

      assert(#all_tl_files > 0, "Could not find any .tl files at the given path")

      for _, subpath in ipairs(all_tl_files) do
         run_teal_check_on_file(subpath, env, results)
      end
   end

   for name in ivalues(env.loaded_order) do
      local res = env.loaded[name]
      add_result(results, res)
   end

   return results
end

local function construct_lua_path(paths)
   local result = ""

   for _, path in ipairs(paths) do
      if #result ~= 0 then
         result = result .. ";"
      end
      result = result .. path .. "?.lua;" .. path .. "?/init.lua"
   end

   return result
end

local function adjust_error_message(message)

   message = message:gsub("\n", " ")
   return message
end

local function print_errors(results)
   local seen_errors = {}

   for _, err in ipairs(results.errors) do
      local line = string.format("error:%s:%s:%s:%s", err.filename, err.y, err.x, adjust_error_message(err.msg))
      if seen_errors[line] == nil then
         seen_errors[line] = true
         print(line)
      end
   end

   local seen_warnings = {}

   for _, warning in ipairs(results.warnings) do
      local line = string.format("warning:%s:%s:%s:%s", warning.filename, warning.y, warning.x, adjust_error_message(warning.msg))
      if seen_warnings[line] == nil then
         seen_warnings[line] = true
         print(line)
      end
   end
end

local function get_path_from_args()
   local path = arg[1]

   if not path_is_absolute(path) then
      local cwd = lfs.currentdir()
      assert(cwd, "Failed to obtain current directory")
      path = path_join(cwd, path)
   end

   return path
end

local function main()
   local path_to_check = get_path_from_args()

   local tlconfig_path = try_find_tlconfig_path(path_to_check)
   assert(tlconfig_path ~= nil, "Unable to find a tlconfig.lua file!  Searched given path and all parents")

   local tlconfig = dofile(tlconfig_path)

   local include_dirs = process_include_dir_arg(tlconfig.include_dir, tlconfig_path)
   local global_modules = process_global_env_def_arg(tlconfig.global_env_def)

   package.path = construct_lua_path(include_dirs)
   package.cpath = ""

   local results = run_teal_check(tlconfig_path, path_to_check, global_modules)

   print_errors(results)

   if #results.errors > 0 then
      os.exit(1)
   end
end

main()
