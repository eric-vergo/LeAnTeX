-- Released under Apache 2.0 license as described in the file LICENSE.
-- Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
--
-- TeX's answers for the document corpus (corpus/doc/*.tex), recorded inside a LuaLaTeX run that
-- tools/doc-reference.sh starts through doc-reference.tex. For every page shipped out it records
--   * the page number (\count0) and the page's size;
--   * every line of the page: an hlist that holds a glyph directly and is not inside another
--     such hlist, with the position of its left edge and baseline from the paper's top left
--     corner (TeX's origin is one inch in and down) and its text;
--   * every rule (its left edge, top, width and height);
--   * the vertical list of the text body (the vlist as tall as \textheight): its items with
--     their sizes, nested vlists with theirs (floats, footnotes), hlists by size and text only.
-- Counter steps are recorded by doc-reference.tex (\stepcounter and \refstepcounter with the
-- counter's printed value); at the end of the run the labels of the auxiliary file and the
-- entries of the table of contents are added. Lengths are in sp; glue orders are LuaTeX's
-- (0 finite, 2 fil, 3 fill, 4 filll). One JSON document is written per run.
-- Why Lua: the shipped page exists only inside TeX; the pre_shipout_filter callback hands it
-- over as nodes.

local GLYPH, GLUE, KERN, PENALTY, DISC, HLIST, VLIST, RULE, MATH =
  node.id("glyph"), node.id("glue"), node.id("kern"), node.id("penalty"), node.id("disc"),
  node.id("hlist"), node.id("vlist"), node.id("rule"), node.id("math")

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

local pages, counters = {}, {}

-- The text of a list: characters of glyphs (ligatures as their components when the font
-- records them), a space for glue, the replacement text of discretionaries; nested lists too.
local function textOf(head, out)
  for n in node.traverse(head) do
    if n.id == GLYPH then
      local comps = n.components
      if comps then textOf(comps, out) else out[#out + 1] = utf8.char(n.char) end
    elseif n.id == GLUE then
      if n.width > 0 or n.stretch > 0 then out[#out + 1] = " " end
    elseif n.id == DISC then textOf(n.replace, out)
    elseif n.id == HLIST or n.id == VLIST then textOf(n.head, out)
    end
  end
  return out
end
local function text(head) return (table.concat(textOf(head, {})):gsub("  +", " ")) end

local function hasGlyph(head)
  for n in node.traverse(head) do
    if n.id == GLYPH or n.id == DISC then return true end
  end
  return false
end

-- The glue a set box gives its glue items, as TeX's hlist_out and vlist_out compute it: the
-- stretch (or shrink) of the set order is accumulated and the running total rounded, so the
-- rounding errors do not add up. Returns a function from a glue node to its size.
local RUNNING = -1073741824
local function glueSizer(box)
  local total, done = 0.0, 0
  return function(g)
    local w = g.width
    if box.glue_sign == 1 and g.stretch_order == box.glue_order then
      total = total + g.stretch
      local now = math.floor(box.glue_set * total + 0.5)
      w, done = w + now - done, now
    elseif box.glue_sign == 2 and g.shrink_order == box.glue_order then
      total = total - g.shrink
      local now = math.floor(box.glue_set * total + 0.5)
      w, done = w + now - done, now
    end
    return w
  end
end

-- The lines and rules of a box placed with its reference point at (x, y) (y its baseline for
-- an hlist, its top for a vlist), as TeX's shipout places them. A line inside a line (an
-- \mbox in a paragraph) is part of the outer one.
local lines, rules
local function rule(x, top, w, h)
  if w > 0 and h > 0 then
    rules[#rules + 1] = { x, top, w, h }
  end
end
local function outList(n, x, y, inLine)
  if n.id == HLIST then
    local line = not inLine and hasGlyph(n.head)
    if line then
      lines[#lines + 1] = obj { { "x", x }, { "y", y }, { "w", n.width }, { "h", n.height },
        { "d", n.depth }, { "text", text(n.head) } }
    end
    local cx, size = x, glueSizer(n)
    for c in node.traverse(n.head) do
      if c.id == HLIST or c.id == VLIST then
        if c.id == HLIST then outList(c, cx, y + c.shift, inLine or line)
        else outList(c, cx, y + c.shift - c.height, inLine or line) end
        cx = cx + c.width
      elseif c.id == GLUE then cx = cx + size(c)
      elseif c.id == KERN then cx = cx + c.kern
      elseif c.id == RULE then
        local h = c.height == RUNNING and n.height or c.height
        local d = c.depth == RUNNING and n.depth or c.depth
        rule(cx, y - h, c.width, h + d)
        cx = cx + c.width
      elseif c.id == GLYPH then cx = cx + c.width
      elseif c.id == MATH then cx = cx + (c.width or c.surround or 0)
      end
    end
  elseif n.id == VLIST then
    local cy, size = y, glueSizer(n)
    for c in node.traverse(n.head) do
      if c.id == HLIST then
        cy = cy + c.height
        outList(c, x + c.shift, cy, inLine)
        cy = cy + c.depth
      elseif c.id == VLIST then
        outList(c, x + c.shift, cy, inLine)
        cy = cy + c.height + c.depth
      elseif c.id == GLUE then cy = cy + size(c)
      elseif c.id == KERN then cy = cy + c.kern
      elseif c.id == RULE then
        local w = c.width == RUNNING and n.width or c.width
        rule(x, cy, w, c.height + c.depth)
        cy = cy + c.height + c.depth
      end
    end
  end
end

local function glueItem(g)
  return { "glue", g.width, g.stretch, g.stretch_order, g.shrink, g.shrink_order, g.subtype }
end

-- A vertical list's items; nested vlists in full, hlists by size and text.
local function vitems(head)
  local out = {}
  for n in node.traverse(head) do
    if n.id == HLIST then
      out[#out + 1] = { "h", n.width, n.height, n.depth, n.shift, text(n.head) }
    elseif n.id == VLIST then
      out[#out + 1] = { "v", n.width, n.height, n.depth, n.shift, n.glue_sign, n.glue_order,
        n.glue_set, vitems(n.head) }
    elseif n.id == GLUE then out[#out + 1] = glueItem(n)
    elseif n.id == KERN then out[#out + 1] = { "k", n.kern, n.subtype }
    elseif n.id == PENALTY then out[#out + 1] = { "p", n.penalty }
    elseif n.id == RULE then out[#out + 1] = { "rule", n.width, n.height, n.depth }
    else out[#out + 1] = { "o", node.type(n.id) }
    end
  end
  return out
end

-- The text body: the first vlist (breadth first) as tall as \textheight.
local function body(box)
  local queue, i = { box }, 1
  local th = tex.dimen.textheight
  while i <= #queue and i < 200 do
    local n = queue[i]; i = i + 1
    if n.id == VLIST and n.height == th and n ~= box then return n end
    if n.id == HLIST or n.id == VLIST then
      for c in node.traverse(n.head) do
        if c.id == HLIST or c.id == VLIST then queue[#queue + 1] = c end
      end
    end
  end
  return nil
end

function leantexShipout(box)
  lines, rules = {}, {}
  local inch = 4736286
  outList(box, inch, inch + (box.id == VLIST and 0 or box.height))
  local b = body(box)
  pages[#pages + 1] = obj {
    { "number", tex.count[0] },
    { "pagewidth", tex.pagewidth }, { "pageheight", tex.pageheight },
    { "lines", lines }, { "rules", rules },
    { "body", b and obj { { "width", b.width }, { "height", b.height }, { "depth", b.depth },
      { "glueSign", b.glue_sign }, { "glueOrder", b.glue_order }, { "glueSet", b.glue_set },
      { "items", vitems(b.head) } } or nil } }
  return true
end

function leantexCounter(kind, name, value, label)
  counters[#counters + 1] = { kind, name, value, label }
end

local function readLines(path)
  local f = io.open(path, "r")
  if not f then return {} end
  local out = {}
  for l in f:lines() do out[#out + 1] = l end
  f:close()
  return out
end

-- The parameters a document's layout depends on, as LaTeX set them.
local function params()
  local d, s, c = tex.dimen, tex.skip, tex.count
  local function g(x) return { x.width, x.stretch, x.stretch_order, x.shrink, x.shrink_order } end
  return obj {
    { "textwidth", d.textwidth }, { "textheight", d.textheight }, { "topskip", g(s.topskip) },
    { "parskip", g(s.parskip) }, { "parindent", d.parindent },
    { "baselineskip", g(s.baselineskip) }, { "oddsidemargin", d.oddsidemargin },
    { "topmargin", d.topmargin }, { "headheight", d.headheight }, { "headsep", d.headsep },
    { "footskip", d.footskip }, { "maxdepth", d.maxdepth },
    { "widowpenalty", c.widowpenalty }, { "clubpenalty", c.clubpenalty } }
end

function leantexFinish(path, banner, job)
  local labels, toc = {}, {}
  for _, l in ipairs(readLines(job .. ".aux")) do
    if l:match("^\\newlabel") then labels[#labels + 1] = l end
    local entry = l:match("^\\@writefile{toc}(.*)$")
    if entry then toc[#toc + 1] = entry end
  end
  local f = assert(io.open(path, "w"))
  f:write(encode(obj {
    { "meta", obj { { "engine", banner }, { "format", tex.formatname or "" } } },
    { "params", params() },
    { "pages", pages }, { "counters", counters }, { "labels", labels }, { "toc", toc } }))
  f:write("\n")
  f:close()
end

luatexbase.add_to_callback("pre_shipout_filter", leantexShipout, "leantex.doc-reference")
