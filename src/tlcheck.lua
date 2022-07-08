local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table
if #arg ~= 1 then
   print("Teal Check\nUsage: teal-check [PATH]\nNote:\n - Given path can be a single .tl file or a directory (which will be searched recursively for all .tl files)\n - A tlconfig.lua file must be present in the given directory or a parent of the given directory/path\n - This program is designed to be more script/machine friendly than human friendly.  The output is easy to parse but not easy to read")
   os.exit(1)
end




local lfs = require("lfs")
local tl = require("tl")

local TealConfig = {}




local function get_parent_path(path)
   return path:match('(.*[/\\]).+')
end

local function path_is_absolute(path)
   local first_char = path:sub(1, 1)
   return first_char == "/" or first_char == "\\"
end

local function path_has_trailing_slash(path)
   local last_char = path:sub(#path)
   return last_char == "/" or last_char == "\\"
end

local function get_sub_paths(path)
   assert(lfs.attributes(path, "mode") == "directory")

   local result = {}

   for sub_path in lfs.dir(path) do


      if sub_path:sub(1, 1) ~= "." then
         table.insert(result, sub_path)
      end
   end

   return result
end

local function try_find_tlconfig_path(start_search_path)
   assert(#start_search_path > 0, "Invalid path given")
   assert(path_is_absolute(start_search_path))

   local search_dir
   local file_type = lfs.attributes(start_search_path, "mode")

   if file_type == "directory" then
      search_dir = start_search_path
      assert(path_has_trailing_slash(search_dir))
   else
      assert(file_type == "file", "Invalid path given")
      search_dir = get_parent_path(start_search_path)
   end

   while search_dir ~= nil do
      for _, sub_path in ipairs(get_sub_paths(search_dir)) do
         local full_path = search_dir .. sub_path
         if sub_path == "tlconfig.lua" and lfs.attributes(full_path, "mode") == "file" then
            return full_path
         end
      end

      search_dir = get_parent_path(search_dir)
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
   local tlconfig_dir = get_parent_path(tlconfig_path)

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

local CheckResults = {}




local function run_teal_check_on_file(path, global_modules)


   local env, env_error = tl.init_env(
   false, nil, nil, global_modules)

   if env == nil then
      error("Failed to initialize teal environment!  Details: " .. env_error)
   end

   local result, process_error = tl.process(path, env)

   if process_error ~= nil then
      error("Error while processing file '" .. path .. "': " .. process_error)
   end

   local all_errors = {}
   local all_warnings = {}

   if result.warnings then
      for _, err in ipairs(result.warnings) do
         table.insert(all_warnings, err)
      end
   end

   if result.syntax_errors then
      for _, err in ipairs(result.syntax_errors) do
         table.insert(all_errors, err)
      end
   end

   if result.type_errors then
      for _, err in ipairs(result.type_errors) do
         table.insert(all_errors, err)
      end
   end

   return {
      errors = all_errors,
      warnings = all_warnings,
   }
end

local function get_all_tl_files_in_directory_recursive(start_path)
   assert(lfs.attributes(start_path, "mode") == "directory")
   assert(path_has_trailing_slash(start_path))

   local queue = { start_path }
   local result = {}

   while #queue > 0 do
      local search_dir = queue[#queue]
      table.remove(queue, #queue)

      for _, path in ipairs(get_sub_paths(search_dir)) do
         local full_path = search_dir .. path
         local path_mode = lfs.attributes(full_path, "mode")

         if path_mode == "directory" then
            if not path_has_trailing_slash(full_path) then
               full_path = full_path .. "/"
            end
            table.insert(queue, full_path)
         elseif path_mode == "file" and path:sub(-3) == ".tl" then
            table.insert(result, full_path)
         end
      end
   end

   return result
end

local function run_teal_check(path, global_modules)
   local path_file_type = lfs.attributes(path, "mode")

   if path_file_type == "file" then
      return run_teal_check_on_file(path, global_modules)
   end

   assert(path_file_type == "directory", "Invalid path given")

   local all_tl_files = get_all_tl_files_in_directory_recursive(path)

   assert(#all_tl_files > 0, "Could not find any .tl files at the given path")

   local all_errors = {}
   local all_warnings = {}

   for _, subpath in ipairs(all_tl_files) do
      local file_results = run_teal_check_on_file(subpath, global_modules)

      for _, err in ipairs(file_results.errors) do
         table.insert(all_errors, err)
      end

      for _, err in ipairs(file_results.warnings) do
         table.insert(all_warnings, err)
      end
   end

   return {
      errors = all_errors,
      warnings = all_warnings,
   }
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
   for _, err in ipairs(results.errors) do
      print(string.format("error:%s:%s:%s:%s", err.filename, err.y, err.x, adjust_error_message(err.msg)))
   end

   for _, warning in ipairs(results.warnings) do
      print(string.format("warning:%s:%s:%s:%s", warning.filename, warning.y, warning.x, adjust_error_message(warning.msg)))
   end
end

local function get_path_from_args()
   local path = arg[1]

   if not path_is_absolute(path) then
      local cwd = lfs.currentdir()
      assert(cwd, "Failed to obtain current directory")

      if not path_has_trailing_slash(cwd) then
         cwd = cwd .. "/"
      end

      path = cwd .. path
   end

   return path
end

local function main()
   local path_to_check = get_path_from_args()
   local path_type = lfs.attributes(path_to_check)

   assert(path_type ~= nil, "Invalid path given")

   if path_type.mode == "directory" and not path_has_trailing_slash(path_to_check) then
      path_to_check = path_to_check .. "/"
   end

   local tlconfig_path = try_find_tlconfig_path(path_to_check)
   assert(tlconfig_path ~= nil, "Unable to find a tlconfig.lua file!  Searched given path and all parents")

   local tlconfig = dofile(tlconfig_path)

   local include_dirs = process_include_dir_arg(tlconfig.include_dir, tlconfig_path)
   local global_modules = process_global_env_def_arg(tlconfig.global_env_def)

   package.path = construct_lua_path(include_dirs)
   package.cpath = ""

   local results = run_teal_check(path_to_check, global_modules)

   print_errors(results)

   if #results.errors > 0 then
      os.exit(1)
   end
end

main()
