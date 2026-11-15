-- Released under Apache 2.0 license as described in the file LICENSE.
-- Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
--
-- Helper of tools/math-codes.sh, run inside LuaLaTeX after amsmath, amssymb and the document
-- fonts are loaded: records how TeX defines each control sequence of a list and each ASCII
-- character in math mode, as tab-separated rows (the layout is documented in math-codes.sh).
-- Each control sequence is looked up by name (`token.create`), its `\meaning` text is read
-- (the same text TeX prints) and parsed; names reach TeX only through Lua strings, so no name
-- needs escaping. Characters are read with `tex.getmathcode` and `tex.getdelcode`.

local rows = {}

-- Escapes tabs, newlines and carriage returns of a field (backslash is kept as it is).
local function esc(s)
  return (s:gsub("[\t\n\r]", { ["\t"] = "\\t", ["\n"] = "\\n", ["\r"] = "\\r" }))
end

-- Appends the row `name, kind, note, fields...` (fields are numbers or strings).
local function row(name, kind, note, ...)
  local parts = { esc(name), kind, esc(note) }
  for _, f in ipairs({ ... }) do parts[#parts + 1] = esc(tostring(f)) end
  rows[#rows + 1] = table.concat(parts, "\t")
end

-- The `\meaning` text of the control sequence with the given name (which must be defined),
-- by expanding `\meaning` inside `\csname` so that any name, even with spaces, is supported.
local function meaning(name)
  tex.runtoks(function()
    tex.sprint("\\xdef\\leantexmeaning{\\expandafter\\meaning\\csname ")
    tex.sprint(-2, name)
    tex.sprint("\\endcsname}")
  end)
  return token.get_macro("leantexmeaning")
end

-- Splits a 15-bit mathchar value into class, family and slot.
local function split15(v) return v >> 12, (v >> 8) & 15, v & 255 end

-- Splits a 24-bit delimiter value into small family, small slot, large family, large slot.
local function split24(v) return (v >> 20) & 15, (v >> 12) & 255, (v >> 8) & 15, v & 255 end

-- The value of a TeX number written as "HEX or in decimal.
local function num(s)
  if s:sub(1, 1) == '"' then return tonumber(s:sub(2), 16) end
  return tonumber(s)
end

-- Records the row for a primitive-valued text `body` (what a macro expands to or a meaning
-- reads) if it is exactly a \mathchar, \delimiter, \mathaccent or \radical (or U-form) call.
-- Returns true when a row was written.
local function record_value(name, note, body)
  local t = body:gsub("^%s+", ""):gsub("%s+$", "")
  local h
  h = t:match('^\\mathchar ?("?%x+)$')
  if h then row(name, "mathchar", note, split15(num(h))) return true end
  local c, f, s = t:match('^\\Umathchar ?"(%x+) ?"(%x+) ?"(%x+)$')
  if c then row(name, "mathchar", note, tonumber(c, 16), tonumber(f, 16), tonumber(s, 16)) return true end
  h = t:match('^\\delimiter ?("?%x+)$')
  if h then
    local v = num(h)
    row(name, "delimiter", note, (v >> 24) & 7, split24(v & 0xFFFFFF)) return true
  end
  h = t:match('^\\mathaccent ?("?%x+)$')
  if h then row(name, "mathaccent", note, split15(num(h))) return true end
  c, f, s = t:match('^\\Umathaccent ?"(%x+) ?"(%x+) ?"(%x+)$')
  if c then row(name, "mathaccent", note, tonumber(c, 16), tonumber(f, 16), tonumber(s, 16)) return true end
  h = t:match('^\\radical ?("?%x+)$')
  if h then row(name, "radical", note, split24(num(h) & 0xFFFFFF)) return true end
  return false
end

-- Records one control sequence `\name` (given without the backslash).
local function record_cs(name)
  local shown = "\\" .. name
  if token.create(name).cmdname == "undefined_cs" then
    row(shown, "undefined", "-") return
  end
  local m = meaning(name)
  local prefix, rest = m:match("^([\\%a ]*)macro:(.*)$")
  if prefix and prefix:match("^[\\protectedlongout ]*$") then
    row(shown, "macro", "-", m)
    local b = rest:match("^.-%->(.*)$") or ""
    -- A \protect wrapper: LaTeX's robust commands expand to `\protect \name<space>`.
    local inner = name .. " "
    if b:match("^\\protect ") and token.create(inner).cmdname ~= "undefined_cs" then
      local im = meaning(inner)
      local note = "inner:" .. inner
      local ip, irest = im:match("^([\\%a ]*)macro:(.*)$")
      if ip then
        row(shown, "macro", note, im)
        record_value(shown, note, (irest:match("^.-%->(.*)$") or ""))
      elseif not record_value(shown, note, im) then
        row(shown, "other", note, im)
      end
    else
      record_value(shown, "inner:body", b)
    end
    return
  end
  if record_value(shown, "-", m) then return end
  if m == "\\" .. name then row(shown, "primitive", "-", m) return end
  row(shown, "other", "-", m)
end

-- Records the \mathcode and \delcode of the character with code `c`.
local function record_char(c)
  local ch = utf8.char(c)
  local mc = tex.getmathcode(c)
  row(ch, "mathcode", "-", mc[1], mc[2], mc[3])
  local dc = tex.getdelcode(c)
  if dc[1] < 0 then row(ch, "delcode", "-", -1)
  else row(ch, "delcode", "-", dc[1], dc[2], dc[3], dc[4]) end
end

-- Records every `\sym<name>` family number LaTeX defines (symbol fonts are `\char` constants).
local function record_families()
  for _, n in ipairs(tex.hashtokens()) do
    if n:match("^sym%a") and token.create(n).cmdname == "char_given" then
      local m = meaning(n)
      local v = m:match('^\\char"(%x+)$')
      if v then row("\\" .. n, "family", "-", tonumber(v, 16)) end
    end
  end
end

-- Reads the names file (one control sequence per line, backslash included) and writes all rows
-- to `outfile`, sorted by name, kind and note with the recording order kept for ties.
function leantexMathCodes(namesfile, outfile)
  for line in io.lines(namesfile) do
    if line:sub(1, 1) == "\\" and #line > 1 then record_cs(line:sub(2)) end
  end
  for c = 0x21, 0x7E do record_char(c) end
  record_families()
  local keyed = {}
  for i, r in ipairs(rows) do
    keyed[i] = { r:match("^[^\t]*"), i, r }
  end
  table.sort(keyed, function(a, b)
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
  end)
  local f = assert(io.open(outfile, "w"))
  for _, k in ipairs(keyed) do f:write(k[3], "\n") end
  f:close()
end
