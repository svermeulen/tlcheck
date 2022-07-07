package = "tlcheck"
version = "0.1"
source = {
   url = "git@github.com:svermeulen/tlcheck.git"
}
description = {
   summary = "Simple command line tool to type check a given teal file/directory",
   detailed = "Simple command line tool to type check a given teal file/directory",
   homepage = "https://github.com/svermeulen/tlcheck",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "luafilesystem >= 1.5.0",
}
build = {
   type = "builtin",
   modules = {
      tlcheck = "src/tlcheck.lua"
   }
}