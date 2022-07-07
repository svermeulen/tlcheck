
if #arg ~= 1 then
   print("Teal Check\nUsage: teal-check [PATH]\nNote:\n- Given path can be a single .tl file or a directory (which will be searched recursively for all .tl files)\n- A tlconfig.lua file must be present in the given directory or a parent of the given directory/path")
   os.exit(1)
end

local lfs <const> = require("lfs")
local tl <const> = require("tl")

local record TealConfig
   include_dir:{string}
   global_env_def:string
end

local function get_parent_path(path:string):string
   return path:match('(.*[/\\]).+')
end

local function try_find_tlconfig_path(start_search_path:string):string
   assert(#start_search_path > 0)

   local search_dir:string
   local file_type = lfs.attributes(start_search_path, "mode")

   if file_type == "directory" then
      search_dir = start_search_path

      local last_char = search_dir:sub(#search_dir - 1)
      if last_char ~= "/" and last_char ~= "\\" then
         search_dir = search_dir .. "/"
      end
   else
      assert(file_type == "file", "Invalid path given")
      search_dir = get_parent_path(start_search_path)
   end

   while search_dir ~= nil do
      for sub_path in lfs.dir(search_dir) do
         if sub_path == "tlconfig.lua" then
            return search_dir .. sub_path
         end
      end

      search_dir = get_parent_path(search_dir)
   end

   return nil
end

local function process_include_dir_arg(include_dir:string|{string}, tlconfig_path:string):{string}
   if include_dir == nil then
      return {}
   end

   local all_dirs = {}

   if include_dir is string then
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
         local first_char = dir:sub(0)
         local is_absolute = first_char == "/" or first_char == "\\"

         if not is_absolute then
            dir = tlconfig_dir .. dir
         end

         local last_char = dir:sub(#dir)
         if last_char ~= "/" and last_char ~= "\\" then
            dir = dir .. "/"
         end

         table.insert(adjusted_dirs, dir)
      end
   end

   return adjusted_dirs
end

local function process_global_env_def_arg(global_env_def:string|{string}):{string}
   if global_env_def is string then
      return {global_env_def}
   end
   return global_env_def as {string}
end

local function run_teal_check(path:string, global_modules:{string}):{tl.Error}
   local env, env_error = tl.init_env(
      false, nil, nil, global_modules)

   if env == nil then
      error("Failed to initialize teal environment!  Details: " .. tostring(env_error))
   end

   local result, process_error = tl.process(path, env)

   if process_error ~= nil then
      error("Error while processing file '" .. path .. "': " .. process_error)
   end

   local all_errors:{tl.Error} = {}

   if result.warnings then
      for _, err in ipairs(result.warnings) do
         table.insert(all_errors, err)
      end
   end

   for _, err in ipairs(result.syntax_errors) do
      table.insert(all_errors, err)
   end

   for _, err in ipairs(result.type_errors) do
      table.insert(all_errors, err)
   end

   return all_errors
end

local function construct_lua_path(paths:{string}):string
   local result = ""

   for _, path in ipairs(paths) do
      if #result ~= 0 then
         result = result .. ";"
      end
      result = result .. path .. "?.lua;" .. path .. "?/init.lua"
   end

   return result
end

local function print_errors(errors:{tl.Error})
   for _, err in ipairs(errors) do
      print(string.format("%s:%s:%s:%s", err.filename, err.y, err.x, err.msg))
   end
end

local function main()
   local path_to_check = arg[1]

   assert(lfs.attributes(path_to_check) ~= nil, "Invalid path given")

   local tlconfig_path = try_find_tlconfig_path(path_to_check)
   assert(tlconfig_path ~= nil, "Unable to find a tlconfig.lua file for given path.  Searched in parent directories.")

   local tlconfig:TealConfig = dofile(tlconfig_path) as TealConfig

   local include_dirs = process_include_dir_arg(tlconfig.include_dir, tlconfig_path)
   local global_modules = process_global_env_def_arg(tlconfig.global_env_def)

   package.path=construct_lua_path(include_dirs)
   package.cpath=""

   local errors = run_teal_check(path_to_check, global_modules)

   print_errors(errors)

   if #errors > 0 then
      os.exit(1)
   end
end

main()
