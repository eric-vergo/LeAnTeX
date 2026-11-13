/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeXTest.Cases

/-!
# Display lists as JSON

`lake exe leantex-display CORPUS…` lays out every formula of the corpora and prints one JSON
line per formula LeAnTeX lays out: the id, the formula, the display flag, whether a character
has no metrics of its own, where the equation tag starts, the width, height and depth, the items
(`["g", face, char, x, y, size, exact]`, `"s"` for a shadow glyph, `["r", x, y, width, height]`,
`["p", x, y, width, height]`) and the item ranges of the lines. `tools/check-display.mjs`
compares them with the positions a browser gives KaTeX's rendering.
-/

open LeAnTeX

/-- An item as JSON. -/
def itemJson : Item → Json
  | .glyph f c x y s e sh _ _ =>
    .arr #[.str (if sh then "s" else "g"), .str f.name, .str c.toString, x.toJson, y.toJson,
      s.toJson, .bool e]
  | .rule x y w h _ _ => .arr #[.str "r", x.toJson, y.toJson, w.toJson, h.toJson]
  | .path _ _ _ x y w h _ _ _ => .arr #[.str "p", x.toJson, y.toJson, w.toJson, h.toJson]

/-- Print the display lists of the corpora named on the command line. -/
def main (args : List String) : IO UInt32 := do
  for name in args do
    for j in ← readJsonLines s!"corpus/{name}.jsonl" do
      let some id := (j.get? "id").bind Json.getStr? | continue
      let tex := ((j.get? "tex").bind Json.getStr?).getD ""
      let settings := caseSettings j
      let r := layout tex settings
      match r.result with
      | .ok b =>
        let d := DisplayList.ofBox b
        -- a character KaTeX has no metrics for: the browser advances by a font's own width
        let noMetrics := d.items.any fun
          | .glyph _ _ _ _ _ exact _ _ _ => !exact
          | _ => false
        let tagX := (d.parts.find? (·.tag)).map (·.x)
        IO.println (Json.obj #[("id", .str id), ("tex", .str tex),
          ("display", .bool settings.displayMode), ("noMetrics", .bool noMetrics),
          ("settings", (j.get? "settings").getD .null),
          ("macros", (j.get? "macros").getD .null), ("width", d.width.toJson),
          ("height", d.height.toJson), ("depth", d.depth.toJson),
          ("tagX", match tagX with | some x => x.toJson | none => .null),
          ("items", .arr (d.items.map itemJson)),
          ("lines", .arr (d.lines.map fun ln => .arr #[.num ln.start.toFloat,
            .num ln.stop.toFloat]))]).compress
      | .error _ => pure ()
  return 0
