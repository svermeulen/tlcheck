
# Teal Check

A simple command line tool to type check a given [teal](https://github.com/teal-language/tl) file/directory and produce a list of warnings/errors

# Installation

*From luarocks*

* `luarocks install tlcheck`
* `tlcheck`

*From source*

* Clone repo
* From repo root:
  * `luarocks init`
  * `./luarocks make`
  * `./lua_modules/bin/tlcheck`

# Usage

```
tlcheck [PATH]
```

Note:

* Given path can be a single .tl file or a directory (which will be searched recursively for all .tl files)
* A tlconfig.lua file must be present in the given directory or a parent of the given directory/path
* This program is designed to be more script/machine friendly than human friendly.  The output is easy to parse but not easy to read.  When no errors are found, there is zero output and the exit code is 0 (and otherwise will be 1)

# FAQ

_Doesn't [cyan](https://github.com/teal-language/cyan) already do this?_

Yes. [cyan](https://github.com/teal-language/cyan) would be a better choice when building/type-checking your teal scripts on the command line.  However, the output from cyan [is not currently very script friendly](https://github.com/teal-language/cyan/issues/21).  So tlcheck just fills that one particular gap.

The [tl](https://github.com/teal-language/tl/blob/master/tl) script that comes with teal also provides some of this functionality, however [it appears to be deprecated](https://github.com/teal-language/tl/blob/ce5c741efde0c7417ca443eb268a744e2fd738c4/tl#L253) in favour of cyan.

