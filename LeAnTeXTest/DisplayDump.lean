/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeXTest.Cases

/-!
# Display lists as JSON

`lake exe leantex-display [--line-width W] CORPUS…` lays out every formula of the corpora and
prints one JSON line per formula LeAnTeX lays out: the id, the formula, the display flag,
whether a character has no metrics of its own, the line width display-mode formulas are placed
in (`W` em, default 40), where the equation tag starts, the width, height and depth, the items
(`["g", face, char, x, y, size, exact, mirrored]`, `"s"` for a shadow glyph,
`["r", x, y, width, height]`, `["p", x, y, width, height, mirrored]`), the colours they are
drawn in, and the item ranges of the lines. `tools/check-display.mjs` compares them with the
positions a browser gives KaTeX's rendering.
-/

open LeAnTeX

/-- An item as JSON; `m` tells whether it is drawn mirrored. -/
def itemJson (m : Bool) : Item → Json
  | .glyph f c x y s e sh _ _ =>
    .arr #[.str (if sh then "s" else "g"), .str f.name, .str c.toString, x.toJson, y.toJson,
      s.toJson, .bool e, .bool m]
  | .rule x y w h _ _ => .arr #[.str "r", x.toJson, y.toJson, w.toJson, h.toJson]
  | .path _ _ _ x y w h _ _ _ =>
    .arr #[.str "p", x.toJson, y.toJson, w.toJson, h.toJson, .bool m]
  | .image _ _ x y w h => .arr #[.str "i", x.toJson, y.toJson, w.toJson, h.toJson]

/-- The colour an item is drawn in, if one is set. -/
def itemColor : Item → Option String
  | .glyph _ _ _ _ _ _ _ c _ | .rule _ _ _ _ c _ | .path _ _ _ _ _ _ _ _ c _ => c
  | .image .. => none

/-- Print the display lists of the corpora named on the command line. -/
def main (args : List String) : IO UInt32 := do
  let (lineWidth, args) : Em × List String := match args with
    | "--line-width" :: w :: rest => (Em.ofFloat (w.toNat?.getD 40).toFloat, rest)
    | rest => (40, rest)
  for name in args do
    for j in ← readJsonLines s!"corpus/{name}.jsonl" do
      let some id := (j.get? "id").bind Json.getStr? | continue
      let tex := ((j.get? "tex").bind Json.getStr?).getD ""
      let settings := caseSettings j
      let r := layout tex settings
      match r.result with
      | .ok b =>
        let d := DisplayList.ofBox b { lineWidth := some lineWidth }
        let mirrored (i : Nat) : Bool := d.mirrored.any fun (a, z) => a ≤ i && i < z
        -- a character KaTeX has no metrics for: the browser advances by a font's own width
        let noMetrics := d.items.any fun
          | .glyph _ _ _ _ _ exact _ _ _ => !exact
          | _ => false
        let tagX := (d.parts.find? (·.tag)).map (·.x)
        IO.println (Json.obj #[("id", .str id), ("tex", .str tex),
          ("display", .bool settings.displayMode), ("noMetrics", .bool noMetrics),
          ("lineWidth", lineWidth.toJson),
          ("settings", (j.get? "settings").getD .null),
          ("macros", (j.get? "macros").getD .null), ("width", d.width.toJson),
          ("height", d.height.toJson), ("depth", d.depth.toJson),
          ("tagX", match tagX with | some x => x.toJson | none => .null),
          ("items", .arr (d.items.mapIdx fun i it => itemJson (mirrored i) it)),
          ("colors", .arr ((d.items.filterMap itemColor).toList.eraseDups.toArray.map .str)),
          ("lines", .arr (d.lines.map fun ln => .arr #[.num ln.start.toFloat,
            .num ln.stop.toFloat]))]).compress
      | .error _ => pure ()
  return 0
