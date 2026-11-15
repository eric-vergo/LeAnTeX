/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Common

/-!
# Stretchy images

The SVG images KaTeX stretches to the width of what they cover: wide accents (`\widehat`,
`\widetilde`, `\widecheck`, `\utilde`), arrows over and under material and of `\xrightarrow`,
horizontal braces and brackets. A single image is a very wide path shown through a clipping
span; two or three pieces (the halves of a double arrow, the ends and middle of a brace) are
clipped to their share of the width.

## Main definitions

* `stretchySvg`: the image for a label and the parse node it decorates.

## References

* KaTeX's `src/stretchy.ts` (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- The pieces of a stretchy image: path names, least width (em), viewBox height, and for a
single path its alignment (`katexImagesData`). -/
def katexImagesData : String → Option (Array String × Em × Nat × Option String)
  | "overrightarrow" => some (#["rightarrow"], 0.888, 522, some "xMaxYMin")
  | "overleftarrow" => some (#["leftarrow"], 0.888, 522, some "xMinYMin")
  | "underrightarrow" => some (#["rightarrow"], 0.888, 522, some "xMaxYMin")
  | "underleftarrow" => some (#["leftarrow"], 0.888, 522, some "xMinYMin")
  | "xrightarrow" => some (#["rightarrow"], 1.469, 522, some "xMaxYMin")
  | "\\cdrightarrow" => some (#["rightarrow"], 3.0, 522, some "xMaxYMin")
  | "xleftarrow" => some (#["leftarrow"], 1.469, 522, some "xMinYMin")
  | "\\cdleftarrow" => some (#["leftarrow"], 3.0, 522, some "xMinYMin")
  | "Overrightarrow" => some (#["doublerightarrow"], 0.888, 560, some "xMaxYMin")
  | "xRightarrow" => some (#["doublerightarrow"], 1.526, 560, some "xMaxYMin")
  | "xLeftarrow" => some (#["doubleleftarrow"], 1.526, 560, some "xMinYMin")
  | "overleftharpoon" => some (#["leftharpoon"], 0.888, 522, some "xMinYMin")
  | "xleftharpoonup" => some (#["leftharpoon"], 0.888, 522, some "xMinYMin")
  | "xleftharpoondown" => some (#["leftharpoondown"], 0.888, 522, some "xMinYMin")
  | "overrightharpoon" => some (#["rightharpoon"], 0.888, 522, some "xMaxYMin")
  | "xrightharpoonup" => some (#["rightharpoon"], 0.888, 522, some "xMaxYMin")
  | "xrightharpoondown" => some (#["rightharpoondown"], 0.888, 522, some "xMaxYMin")
  | "xlongequal" => some (#["longequal"], 0.888, 334, some "xMinYMin")
  | "\\cdlongequal" => some (#["longequal"], 3.0, 334, some "xMinYMin")
  | "xtwoheadleftarrow" => some (#["twoheadleftarrow"], 0.888, 334, some "xMinYMin")
  | "xtwoheadrightarrow" => some (#["twoheadrightarrow"], 0.888, 334, some "xMaxYMin")
  | "overleftrightarrow" => some (#["leftarrow", "rightarrow"], 0.888, 522, none)
  | "overbrace" => some (#["leftbrace", "midbrace", "rightbrace"], 1.6, 548, none)
  | "underbrace" =>
    some (#["leftbraceunder", "midbraceunder", "rightbraceunder"], 1.6, 548, none)
  | "underleftrightarrow" => some (#["leftarrow", "rightarrow"], 0.888, 522, none)
  | "xleftrightarrow" => some (#["leftarrow", "rightarrow"], 1.75, 522, none)
  | "xLeftrightarrow" => some (#["doubleleftarrow", "doublerightarrow"], 1.75, 560, none)
  | "xrightleftharpoons" =>
    some (#["leftharpoondownplus", "rightharpoonplus"], 1.75, 716, none)
  | "xleftrightharpoons" =>
    some (#["leftharpoonplus", "rightharpoondownplus"], 1.75, 716, none)
  | "xhookleftarrow" => some (#["leftarrow", "righthook"], 1.08, 522, none)
  | "xhookrightarrow" => some (#["lefthook", "rightarrow"], 1.08, 522, none)
  | "overlinesegment" => some (#["leftlinesegment", "rightlinesegment"], 0.888, 522, none)
  | "underlinesegment" => some (#["leftlinesegment", "rightlinesegment"], 0.888, 522, none)
  | "overbracket" => some (#["leftbracketover", "rightbracketover"], 1.6, 440, none)
  | "underbracket" => some (#["leftbracketunder", "rightbracketunder"], 1.6, 410, none)
  | "overgroup" => some (#["leftgroup", "rightgroup"], 0.888, 342, none)
  | "undergroup" => some (#["leftgroupunder", "rightgroupunder"], 0.888, 342, none)
  | "xmapsto" => some (#["leftmapsto", "rightarrow"], 1.5, 522, none)
  | "xtofrom" => some (#["leftToFrom", "rightToFrom"], 1.75, 528, none)
  | "xrightleftarrows" => some (#["baraboveleftarrow", "rightarrowabovebar"], 1.75, 901, none)
  | "xrightequilibrium" =>
    some (#["baraboveshortleftharpoon", "rightharpoonaboveshortbar"], 1.75, 716, none)
  | "xleftequilibrium" =>
    some (#["shortbaraboveleftharpoon", "shortrightharpoonabovebar"], 1.75, 716, none)
  | _ => none

/-- The image of a stretchy element (`stretchySvg`): `label` is the command (`\widehat`, …),
`base` the material a wide accent covers. -/
def stretchySvg (label : String) (base : Option Node) (o : Options) : BuildM Box := do
  let label := (label.drop 1).toString
  let (span, minWidth, height) ← do
    if ["widehat", "widecheck", "widetilde", "utilde"].contains label && base.isSome then
      let numChars := match base with
        | some (.ordgroup _ _ body _) => body.size
        | _ => 1
      let hat := label == "widehat" || label == "widecheck"
      let (vbw, vbh, height, pathName) : Nat × Nat × Em × String :=
        if numChars > 5 then
          if hat then (2364, 420, 0.42, label ++ "4") else (2340, 312, 0.34, "tilde4")
        else
          let i := #[1, 1, 2, 2, 3, 3].getD numChars 0
          if hat then
            (#[0, 1062, 2364, 2364, 2364].getD i 0, #[0, 239, 300, 360, 420].getD i 0,
             #[(0 : Em), 0.24, 0.3, 0.3, 0.36, 0.42].getD i 0, label ++ toString i)
          else
            (#[0, 600, 1033, 2339, 2340].getD i 0, #[0, 260, 286, 306, 312].getD i 0,
             #[(0 : Em), 0.26, 0.286, 0.3, 0.306, 0.34].getD i 0, "tilde" ++ toString i)
      let svg : Box :=
        { kind := .svg #[.path pathName none]
          attrs := #[("width", "100%"), ("height", height.css),
            ("viewBox", s!"0 0 {vbw} {vbh}"), ("preserveAspectRatio", "none")] }
      pure (makeSvgSpan #[] #[svg] o, (0 : Em), height)
    else
      let some (paths, minWidth, vbh, align1) := katexImagesData label
        | throwInternal s!"No SVG data for \"{label}\"."
      let height := Em.ofRatio vbh 1000
      let n := paths.size
      let (widthClasses, aligns) : Array String × Array String :=
        if n == 1 then (#["hide-tail"], #[align1.getD ""])
        else if n == 2 then (#["halfarrow-left", "halfarrow-right"], #["xMinYMin", "xMaxYMin"])
        else (#["brace-left", "brace-center", "brace-right"],
              #["xMinYMin", "xMidYMin", "xMaxYMin"])
      let piece (i : Nat) : Box :=
        let svg : Box :=
          { kind := .svg #[.path (paths.getD i default) none]
            attrs := #[("width", "400em"), ("height", height.css),
              ("viewBox", s!"0 0 400000 {vbh}"),
              ("preserveAspectRatio", (aligns.getD i "") ++ " slice")] }
        makeSvgSpan #[(widthClasses.getD i "")] #[svg] o
      if n == 1 then pure (piece 0, minWidth, height)
      else
        let spans := (List.range n).toArray.map fun i => (piece i).setStyle "height" height
        pure (makeSpan #["katex-stretchy"] spans (some o), minWidth, height)
  let span := { span with height }.setStyle "height" height
  return if minWidth > 0 then span.setStyle "minWidth" minWidth else span

end LeAnTeX
