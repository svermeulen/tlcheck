
local record tl
   enum WarningKind
      "unknown"
      "unused"
      "redeclaration"
      "branch"
      "hint"
      "debug"
   end

   record Error
      y: integer
      x: integer
      msg: string
      filename: string

      tag: WarningKind
   end

   enum CompatMode
      "off"
      "optional"
      "required"
   end

   enum TargetMode
      "5.1"
      "5.3"
      "5.4"
   end

   record Env
   end

   record Result
      filename: string
      syntax_errors: {Error}
      type_errors: {Error}
      gen_error: string
      warnings: {Error}
   end

   init_env: function(boolean, boolean | CompatMode, TargetMode, {string}): Env, string
   process: function(string, Env): (Result, string)
end

return tl
