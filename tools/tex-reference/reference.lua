-- Released under Apache 2.0 license as described in the file LICENSE.
-- Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
--
-- TeX's answers for the text-mode corpora, recorded inside a LuaLaTeX run
-- (tools/tex-reference.sh starts it through reference.tex). For each case of a corpus
-- (corpus/text/<name>.jsonl) it typesets the case with real TeX and writes one line of
-- fixtures/text/<name>.jsonl:
--   * a paragraph: the horizontal list the line breaker receives (after hyphenation, ligatures
--     and kerning), the parameters in force, the break chosen for every line, each line's
--     natural width and glue setting, and the total demerits;
--   * a word: its hyphenation points under the patterns and exceptions of the current language;
--   * a box: an \hbox's width, height and depth, and its glyphs, kerns and glue.
-- Lengths are TeX scaled points (sp, 2^-16 pt); glue orders 0..3 are finite, fil, fill, filll.
-- Corpus text is typeset with catcode table -2 (every character other, spaces as spaces), so a
-- corpus can contain no TeX commands; the few control items a case may ask for (penalties, glue,
-- kerns, unbreakable boxes) are validated here and written as TeX by this file.
-- Why Lua: the line breaker's input and output exist only inside TeX; LuaTeX's callbacks
-- (pre_linebreak_filter, linebreak_filter, post_linebreak_filter) hand them over as nodes.

local json = utilities.json -- lualibs' reader, loaded below by reference.tex

local ATTR = 4095 -- an attribute register no LaTeX package allocates this early
local GLYPH, GLUE, KERN, PENALTY, DISC, HLIST, VLIST, RULE, LOCALPAR =
  node.id("glyph"), node.id("glue"), node.id("kern"), node.id("penalty"), node.id("disc"),
  node.id("hlist"), node.id("vlist"), node.id("rule"), node.id("local_par")

-- Ordered JSON output: an object is a list of {key, value} pairs marked with `obj`.
local function obj(pairs_) return setmetatable(pairs_, { __obj = true }) end
local function encode(v)
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" then return v and "true" or "false"
  elseif t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    if v == math.floor(v) and math.abs(v) < 2^53 then return string.format("%d", v) end
    return string.format("%.9g", v)
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      local m = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\t'] = '\\t' }
      return m[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  local parts = {}
  if getmetatable(v) and getmetatable(v).__obj then
    for _, kv in ipairs(v) do parts[#parts + 1] = encode(kv[1]) .. ":" .. encode(kv[2]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  for _, x in ipairs(v) do parts[#parts + 1] = encode(x) end
  return "[" .. table.concat(parts, ",") .. "]"
end

-- The fonts a case uses, in order of first use: index -> {file, size}.
local fontsUsed, fontIndex = {}, {}
local function fontRef(id)
  if fontIndex[id] then return fontIndex[id] end
  local f = font.getfont(id) or {}
  local file = (f.filename or f.name or "?"):match("([^/]+)$")
  fontsUsed[#fontsUsed + 1] = obj { { "file", file }, { "size", f.size or 0 } }
  fontIndex[id] = #fontsUsed - 1
  return fontIndex[id]
end

-- The glyph index of a character in its font (what an OpenType reader calls the glyph id).
local function glyphIndex(n)
  local f = font.getfont(n.font)
  local c = f and f.characters and f.characters[n.char]
  return c and c.index or -1
end

local serialize
-- A node list as items: ["g", char, gid, width, height, depth, font], ["k", width, subtype],
-- ["glue", width, stretch, stretchOrder, shrink, shrinkOrder, subtype], ["p", penalty],
-- ["d", penalty, pre, post, replace, subtype], ["box", width, height, depth, items], ["rule", w, h, d].
local function item(n)
  local id = n.id
  if id == GLYPH then
    return { "g", n.char, glyphIndex(n), n.width, n.height, n.depth, fontRef(n.font) }
  elseif id == KERN then return { "k", n.kern, n.subtype }
  elseif id == GLUE then
    return { "glue", n.width, n.stretch, n.stretch_order, n.shrink, n.shrink_order, n.subtype }
  elseif id == PENALTY then return { "p", n.penalty }
  elseif id == DISC then
    return { "d", n.penalty, serialize(n.pre), serialize(n.post), serialize(n.replace),
      n.subtype }
  elseif id == HLIST or id == VLIST then
    return { "box", n.width, n.height, n.depth, serialize(n.head) }
  elseif id == RULE then return { "rule", n.width, n.height, n.depth }
  end
  return { "other", node.type(id) }
end
serialize = function(head)
  local out = {}
  for n in node.traverse(head) do
    if n.id ~= LOCALPAR then out[#out + 1] = item(n) end
  end
  return out
end

-- The paragraph being recorded: set in pre_linebreak_filter, completed by the later callbacks.
local current = nil

local function glueSpec(g)
  return { g.width, g.stretch, g.stretch_order, g.shrink, g.shrink_order }
end

local function params()
  local p = {}
  for _, k in ipairs { "hsize", "parindent", "emergencystretch" } do
    p[#p + 1] = { k, tex.get(k) }
  end
  for _, k in ipairs { "tolerance", "pretolerance", "looseness", "linepenalty", "hyphenpenalty",
      "exhyphenpenalty", "adjdemerits", "doublehyphendemerits", "finalhyphendemerits",
      "lefthyphenmin", "righthyphenmin", "uchyph", "language" } do
    p[#p + 1] = { k, tex.get(k) }
  end
  for _, k in ipairs { "leftskip", "rightskip", "parfillskip" } do
    p[#p + 1] = { k, glueSpec(tex.get(k)) }
  end
  return obj(p)
end

luatexbase.add_to_callback("pre_linebreak_filter", function(head)
  if not current then return true end
  local items, i = {}, 0
  for n in node.traverse(head) do
    if n.id ~= LOCALPAR then
      node.set_attribute(n, ATTR, i)
      items[#items + 1] = item(n)
      i = i + 1
    end
  end
  current.items = items
  current.params = params()
  return true
end, "leantex.reference.pre")

luatexbase.add_to_callback("linebreak_filter", function(head, isDisplay)
  local newHead, info = tex.linebreak(head)
  if current then current.demerits = info.demerits; current.prevgraf = info.prevgraf end
  return newHead
end, "leantex.reference.linebreak")

-- A line's break: the largest item index among its top-level nodes. TeX keeps the node it breaks
-- at in the line it ends (a glue there becomes the line's \rightskip, so it keeps its index), and
-- every other node of the line comes before it in the list.
luatexbase.add_to_callback("post_linebreak_filter", function(head)
  if not current then return true end
  local lines = {}
  for l in node.traverse(head) do
    if l.id == HLIST then
      local last = -1
      for n in node.traverse(l.head) do
        local a = node.has_attribute(n, ATTR)
        if a and a > last then last = a end
      end
      local natural = node.dimensions(l.head)
      lines[#lines + 1] = obj {
        { "break", last }, { "width", l.width }, { "natural", natural },
        { "glueSign", l.glue_sign }, { "glueOrder", l.glue_order },
        { "glueSet", l.glue_set } }
    end
  end
  current.lines = lines
  return true
end, "leantex.reference.post")

-- A glue specification a case may give: `<n>pt`, optionally `plus <n>pt|fil|fill|filll` and
-- `minus <n>pt|fil|fill|filll`; nil for anything else.
local function validGlue(s)
  if type(s) ~= "string" then return nil end
  local num = "%-?%d+%.?%d*"
  local unit = "pt"
  local inf = "fil+"
  local w, rest = s:match("^(" .. num .. ")pt(.*)$")
  if not w then return nil end
  local out = w .. "pt"
  local function part(word, r)
    local v, u, r2 = r:match("^ " .. word .. " (" .. num .. ")(%a+)(.*)$")
    if not v then return nil, r end
    if u ~= unit and not u:match("^" .. inf .. "$") then return false end
    if #u > 5 then return false end
    return " " .. word .. " " .. v .. u, r2
  end
  local p, r = part("plus", rest)
  if p == false then return nil end
  out = out .. (p or ""); rest = r
  local m, r2 = part("minus", rest)
  if m == false then return nil end
  out = out .. (m or ""); rest = r2
  if rest ~= "" then return nil end
  return out
end

local function isInt(v) return type(v) == "number" and v == math.floor(v) and math.abs(v) < 2^31 end
local function isDim(v) return type(v) == "number" and math.abs(v) < 16000 end

-- The font a case asks for, as LaTeX's font commands.
local fontCommands = {
  regular = "", italic = "\\itshape", bold = "\\bfseries", bolditalic = "\\bfseries\\itshape",
  sans = "\\sffamily", mono = "\\ttfamily", caps = "\\scshape", slanted = "\\slshape" }

local function selectFont(case)
  local cmd = fontCommands[case.font or "regular"]
  if not cmd then error("unknown font " .. tostring(case.font)) end
  local size = case.size or 10
  if not isDim(size) or size <= 0 then error("bad size") end
  tex.sprint(cmd)
  tex.sprint(string.format("\\fontsize{%gpt}{%gpt}\\selectfont", size, size * 1.2))
end

-- The material of a case: its `text`, or its `parts` (strings and control items).
local function material(case)
  local parts = case.parts or { case.text or "" }
  for _, p in ipairs(parts) do
    if type(p) == "string" then tex.sprint(-2, p)
    elseif p.penalty and isInt(p.penalty) then tex.sprint(string.format("\\penalty%d ", p.penalty))
    elseif p.glue then
      local g = validGlue(p.glue)
      if not g then error("bad glue " .. tostring(p.glue)) end
      tex.sprint("\\hskip " .. g .. "\\relax ")
    elseif p.kern and isDim(p.kern) then tex.sprint(string.format("\\kern%gpt ", p.kern))
    elseif p.hbox then tex.sprint("\\hbox{"); tex.sprint(-2, p.hbox); tex.sprint("}")
    elseif p.tie then tex.sprint("~")
    else error("bad part in " .. tostring(case.id)) end
  end
end

local intParams = { "tolerance", "pretolerance", "looseness", "linepenalty", "hyphenpenalty",
  "exhyphenpenalty", "adjdemerits", "doublehyphendemerits", "finalhyphendemerits" }
local dimParams = { "parindent", "emergencystretch" }
local glueParams = { "leftskip", "rightskip", "parfillskip" }

local function paragraph(case)
  if not isDim(case.hsize) or case.hsize <= 0 then error("bad hsize in " .. case.id) end
  current = { id = case.id }
  fontsUsed, fontIndex = {}, {}
  tex.runtoks(function()
    tex.sprint("\\setbox0\\vbox{")
    selectFont(case)
    tex.sprint(string.format("\\hsize=%gpt\\parindent=0pt\\parskip=0pt\\relax ", case.hsize))
    for _, k in ipairs(intParams) do
      if case[k] ~= nil then
        if not isInt(case[k]) then error("bad " .. k) end
        tex.sprint(string.format("\\%s=%d\\relax ", k, case[k]))
      end
    end
    for _, k in ipairs(dimParams) do
      if case[k] ~= nil then
        if not isDim(case[k]) then error("bad " .. k) end
        tex.sprint(string.format("\\%s=%gpt\\relax ", k, case[k]))
      end
    end
    for _, k in ipairs(glueParams) do
      if case[k] ~= nil then
        local g = validGlue(case[k])
        if not g then error("bad " .. k) end
        tex.sprint(string.format("\\%s=%s\\relax ", k, g))
      end
    end
    tex.sprint("\\leavevmode ")
    material(case)
    tex.sprint("\\par}")
  end)
  local c = current
  current = nil
  local box = tex.box[0]
  return obj {
    { "id", case.id }, { "fonts", fontsUsed }, { "params", c.params }, { "items", c.items },
    { "lines", c.lines }, { "demerits", c.demerits }, { "prevgraf", c.prevgraf },
    { "height", box.height }, { "depth", box.depth } }
end

-- The hyphenation points of a word under the current language: the word with `-` at each point.
local function hyphenate(case)
  local word = case.word
  if type(word) ~= "string" or #word > 200 then error("bad word in " .. tostring(case.id)) end
  local head = node.new("glue")
  local tail = head
  for _, c in utf8.codes(word) do
    local g = node.new("glyph")
    g.subtype = 1
    g.char = c; g.font = font.current(); g.lang = tex.language
    g.left = tex.lefthyphenmin; g.right = tex.righthyphenmin; g.uchyph = tex.uchyph
    tail.next = g; g.prev = tail; tail = g
  end
  local e = node.new("glue")
  tail.next = e; e.prev = tail; tail = e
  lang.hyphenate(head, tail)
  local s = {}
  for n in node.traverse(head) do
    if n.id == GLYPH then s[#s + 1] = utf8.char(n.char)
    elseif n.id == DISC then s[#s + 1] = "-" end
  end
  node.flush_list(head)
  return obj { { "id", case.id }, { "word", word }, { "hyphenated", table.concat(s) } }
end

local function hbox(case)
  fontsUsed, fontIndex = {}, {}
  tex.runtoks(function()
    tex.sprint("\\setbox0\\hbox{")
    selectFont(case)
    material(case)
    tex.sprint("}")
  end)
  local b = tex.box[0]
  return obj {
    { "id", case.id }, { "fonts", fontsUsed }, { "width", b.width }, { "height", b.height },
    { "depth", b.depth }, { "items", serialize(b.head) } }
end

local kinds = { paragraph = paragraph, word = hyphenate, hbox = hbox }

-- Runs one corpus file into one fixture file. The first line of the corpus is its `meta`; the
-- fixture's first line names the corpus, the engine and the pattern set.
function leantexReference(corpusPath, fixturePath, banner)
  local inp = assert(io.open(corpusPath, "r"))
  local out = assert(io.open(fixturePath, "w"))
  local first = true
  local count = 0
  for line in inp:lines() do
    if line ~= "" then
      local case = json.tolua(line)
      if first then
        first = false
        local meta = case.meta or {}
        out:write(encode(obj { { "meta", obj {
          { "corpus", meta.corpus or "?" }, { "engine", banner },
          { "luaotfload", luaotfload and luaotfload.version or "?" },
          { "format", tex.formatname or "?" },
          { "lefthyphenmin", tex.lefthyphenmin }, { "righthyphenmin", tex.righthyphenmin },
          { "recorder", "tools/tex-reference.sh" } } } }), "\n")
      else
        local f = kinds[case.kind]
        if not f then error("unknown kind " .. tostring(case.kind)) end
        out:write(encode(f(case)), "\n")
        count = count + 1
      end
    end
  end
  inp:close(); out:close()
  texio.write_nl("leantex-reference: " .. count .. " cases -> " .. fixturePath)
end
