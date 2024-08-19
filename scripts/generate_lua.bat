@echo off
setlocal enabledelayedexpansion
call %~dp0setup_local_luarocks.bat
cd %~dp0\..
del src\tlcheck.lua
call luarocks\bin\tl.bat gen src\tlcheck.tl -o src\tlcheck.lua
