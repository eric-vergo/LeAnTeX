-- Released under Apache 2.0 license as described in the file LICENSE.
-- Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
--
-- The node lists of the formula boxes tools/math-box-reference.sh records: leantexMathBox(n,
-- style) writes box 0 (an \hbox holding one formula) as one JSON line of the output file, with
-- the box's width, height and depth and its whole list, nested lists included, so the test
-- can name the first node where LeAnTeX's box differs from TeX's. A node is an array:
--   ["c", font, size, char, w, h, d]      a glyph (font file name, its size in sp)
--   ["h"|"v", w, h, d, shift, sign, order, set, [nodes]]  a box with its glue setting
--   ["k", w, subtype]   ["g", w, stretch, order, shrink, order, subtype]   ["p", penalty]
--   ["r", w, h, d] (null for a running dimension)   ["m", subtype]   ["?", id]
-- Lengths are in sp; the glue set ratio is written to nine significant digits.
-- Why Lua: the lists exist only inside TeX; the node library reads them.

local GLYPH, GLUE, KERN, PENALTY, HLIST, VLIST, RULE, MATH =
  node.id("glyph"), node.id("glue"), node.id("kern"), node.id("penalty"), node.id("hlist"),
  node.id("vlist"), node.id("rule"), node.id("math")
local RUNNING = -1073741824

-- One JSON value: numbers (integers as such), strings, arrays.
local function encode(v)
  local t = type(v)
  if t == "nil" or v == false then return "null"
  elseif t == "number" then
    if math.type(v) == "integer" then return tostring(v) end
    return string.format("%.9g", v)
  elseif t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      return string.format("\\u%04x", c:byte())
    end) .. '"'
  end
  local parts = {}
  for i = 1, #v do parts[i] = encode(v[i]) end
  return "[" .. table.concat(parts, ",") .. "]"
end

-- The name of a font's file without its extension and directory.
local function fontName(id)
  local f = font.getfont(id)
  if not f then return "?" end
  local name = f.filename or f.name or "?"
  name = name:gsub("^.*/", ""):gsub("%.[%a]+$", "")
  return name
end

local function dim(x) if x == RUNNING then return false end return x end

-- A list as an array of nodes.
local function list(head)
  local out = {}
  for n in node.traverse(head) do
    local id = n.id
    if id == GLYPH then
      out[#out + 1] = { "c", fontName(n.font), font.getfont(n.font).size, n.char, n.width,
        n.height, n.depth }
    elseif id == HLIST or id == VLIST then
      out[#out + 1] = { id == HLIST and "h" or "v", n.width, n.height, n.depth, n.shift,
        n.glue_sign, n.glue_order, n.glue_set + 0.0, list(n.head) }
    elseif id == KERN then out[#out + 1] = { "k", n.kern, n.subtype }
    elseif id == GLUE then
      out[#out + 1] = { "g", n.width, n.stretch, n.stretch_order, n.shrink, n.shrink_order,
        n.subtype }
    elseif id == PENALTY then out[#out + 1] = { "p", n.penalty }
    elseif id == RULE then out[#out + 1] = { "r", dim(n.width), dim(n.height), dim(n.depth) }
    elseif id == MATH then out[#out + 1] = { "m", n.subtype }
    else out[#out + 1] = { "?", id } end
  end
  return out
end

local out
function leantexMathBoxOpen(path) out = io.open(path, "w") end
function leantexMathBox(n, style)
  local b = tex.box[0]
  out:write(encode({ n, style, b.width, b.height, b.depth, list(b.head) }), "\n")
end
function leantexMathBoxClose() out:close() end
