/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Json
import LeAnTeX.Parse.Node

/-!
# Parse trees as JSON

A parse tree in the JSON form of KaTeX's `__parse` output, as the differential harness records
it: KaTeX's field names, fields KaTeX leaves `undefined` omitted, fields it sets to `null`
printed as `null`, and every location as `[start, end]` in UTF-16 code units.

## Main definitions

* `Node.toJson`, `nodesToJson`: a node or a list of nodes.
* `KError.toJson`: an error in the harness's form.

## References

* KaTeX's `src/types/nodes.ts` (the node types and their fields; MIT licence, see
  `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A location field: omitted, `null`, or `[start, end]`. -/
private def locField : OLoc → Array (String × Json)
  | .absent => #[]
  | .null => #[("loc", .null)]
  | .at l => #[("loc", .arr #[.num l.start.toFloat, .num l.stop.toFloat])]

/-- A measurement as `{number, unit}`. -/
def Measurement.toJson (m : Measurement) : Json :=
  .obj #[("number", .num m.number), ("unit", .str m.unit)]

/-- A column specification. -/
def AlignSpec.toJson : AlignSpec → Json
  | .separator s => .obj #[("type", .str "separator"), ("separator", .str s)]
  | .align a pre post => .obj (#[("type", .str "align"), ("align", .str a)] ++
      (pre.map (fun x => #[("pregap", Json.num x)])).getD #[] ++
      (post.map (fun x => #[("postgap", Json.num x)])).getD #[])

/-- A field that KaTeX leaves out when it has no value. -/
private def opt {α : Type} (k : String) (f : α → Json) : Option α → Array (String × Json)
  | some v => #[(k, f v)]
  | none => #[]

/-- A field that KaTeX sets to `null` when it has no value. -/
private def nul {α : Type} (k : String) (f : α → Json) : Option α → Json × String
  | some v => (f v, k)
  | none => (.null, k)

/-- `nul` as a key-value pair. -/
private def nulKV {α : Type} (k : String) (f : α → Json) (v : Option α) : String × Json :=
  let (j, k) := nul k f v
  (k, j)

/-- A token as KaTeX's JSON shows it (text and location). -/
private def tokenJson (t : Token) : Json := .obj (#[("text", .str t.text)] ++ locField t.loc)

mutual

/-- The node in KaTeX's JSON form. -/
partial def Node.toJson (n : Node) : Json :=
  let head := #[("type", Json.str n.type), ("mode", .str n.mode.name)] ++ locField n.loc
  let b := Json.bool
  let s := Json.str
  let ns := nodesToJson
  let fields : Array (String × Json) := match n with
    | .array _ _ cst hs aj cols st body gaps hl tags lq =>
      opt "colSeparationType" s cst ++ opt "hskipBeforeAndAfter" b hs ++ opt "addJot" b aj ++
      opt "cols" (fun cs => .arr (cs.map AlignSpec.toJson)) cols ++
      #[("arraystretch", .num st), ("body", .arr (body.map ns)),
        ("rowGaps", .arr (gaps.map fun g => (nul "" Measurement.toJson g).1)),
        ("hLinesBeforeRow", .arr (hl.map fun r => .arr (r.map b)))] ++
      opt "tags" (fun ts => .arr (ts.map fun
        | .inl x => b x
        | .inr xs => ns xs)) tags ++
      opt "leqno" b lq
    | .cdlabel _ _ side label => #[("side", s side), ("label", label.toJson)]
    | .cdlabelparent _ _ f => #[("fragment", f.toJson)]
    | .color _ _ c body => #[("color", s c), ("body", ns body)]
    | .colorToken _ _ c => #[("color", s c)]
    | .op _ _ lim ahs sbs pis sym name body =>
      #[("limits", b lim)] ++ opt "alwaysHandleSupSub" b ahs ++ opt "suppressBaseShift" b sbs ++
      #[("parentIsSupSub", b pis), ("symbol", b sym)] ++ opt "name" s name ++ opt "body" ns body
    | .ordgroup _ _ body semi => #[("body", ns body)] ++ opt "semisimple" b semi
    | .raw _ _ str => #[("string", s str)]
    | .size _ _ v blank => #[("value", v.toJson), ("isBlank", b blank)]
    | .styling _ _ st rf body => #[("style", s st)] ++ opt "resetFont" b rf ++ #[("body", ns body)]
    | .supsub _ _ base sup sub =>
      #[nulKV "base" Node.toJson base] ++ opt "sup" Node.toJson sup ++ opt "sub" Node.toJson sub
    | .tag _ _ body tag => #[("body", ns body), ("tag", ns tag)]
    | .text _ _ body font => #[("body", ns body)] ++ opt "font" s font
    | .url _ _ u => #[("url", s u)]
    | .verb _ _ body star => #[("body", s body), ("star", b star)]
    | .sym _ _ g t => (if g.isAtom then #[("family", s g.name)] else #[]) ++ #[("text", s t)]
    | .accent _ _ label st sh base =>
      #[("label", s label)] ++ opt "isStretchy" b st ++ opt "isShifty" b sh ++
      #[("base", base.toJson)]
    | .accentUnder _ _ label base => #[("label", s label), ("base", base.toJson)]
    | .cr _ _ nl size => #[("newLine", b nl), nulKV "size" Measurement.toJson size]
    | .delimsizing _ _ size mc d =>
      #[("size", .num size.toFloat), ("mclass", s mc), ("delim", s d)]
    | .enclose _ _ label bg bc body =>
      #[("label", s label)] ++ opt "backgroundColor" s bg ++ opt "borderColor" s bc ++
      #[("body", body.toJson)]
    | .environment _ _ name ng => #[("name", s name), ("nameGroup", ng.toJson)]
    | .font _ _ f body => #[("font", s f), ("body", body.toJson)]
    | .genfrac _ _ cont numer denom bar ld rd bs =>
      #[("continued", b cont), ("numer", numer.toJson), ("denom", denom.toJson),
        ("hasBarLine", b bar), nulKV "leftDelim" s ld, nulKV "rightDelim" s rd,
        nulKV "barSize" Measurement.toJson bs]
    | .hbox _ _ body => #[("body", ns body)]
    | .horizBrace _ _ label over base =>
      #[("label", s label), ("isOver", b over), ("base", base.toJson)]
    | .href _ _ h body => #[("href", s h), ("body", ns body)]
    | .html _ _ attrs body =>
      #[("attributes", .obj (attrs.map fun (k, v) => (k, s v))), ("body", ns body)]
    | .htmlmathml _ _ h m => #[("html", ns h), ("mathml", ns m)]
    | .includegraphics _ _ alt w h th src =>
      #[("alt", s alt), ("width", w.toJson), ("height", h.toJson), ("totalheight", th.toJson),
        ("src", s src)]
    | .infix _ _ rw size tok =>
      #[("replaceWith", s rw)] ++ opt "size" Measurement.toJson size ++ opt "token" tokenJson tok
    | .internal .. => #[]
    | .kern _ _ d => #[("dimension", d.toJson)]
    | .lap _ _ a body => #[("alignment", s a), ("body", body.toJson)]
    | .leftright _ _ body l r rc =>
      #[("body", ns body), ("left", s l), ("right", s r)] ++ opt "rightColor" s rc
    | .leftrightRight _ _ d c => #[("delim", s d)] ++ opt "color" s c
    | .mathchoice _ _ d t sc ss =>
      #[("display", ns d), ("text", ns t), ("script", ns sc), ("scriptscript", ns ss)]
    | .middle _ _ d => #[("delim", s d)]
    | .mclass _ _ mc body cb => #[("mclass", s mc), ("body", ns body), ("isCharacterBox", b cb)]
    | .operatorname _ _ body ahs lim pis =>
      #[("body", ns body), ("alwaysHandleSupSub", b ahs), ("limits", b lim),
        ("parentIsSupSub", b pis)]
    | .overline _ _ body | .underline _ _ body | .vphantom _ _ body | .vcenter _ _ body
    | .reflectbox _ _ body => #[("body", body.toJson)]
    | .phantom _ _ body => #[("body", ns body)]
    | .pmb _ _ mc body => #[("mclass", s mc), ("body", ns body)]
    | .raisebox _ _ dy body => #[("dy", dy.toJson), ("body", body.toJson)]
    | .rule _ _ shift w h =>
      #[nulKV "shift" Measurement.toJson shift, ("width", w.toJson), ("height", h.toJson)]
    | .sizing _ _ size body => #[("size", .num size.toFloat), ("body", ns body)]
    | .smash _ _ body sh sd => #[("body", body.toJson), ("smashHeight", b sh), ("smashDepth", b sd)]
    | .sqrt _ _ body idx => #[("body", body.toJson), nulKV "index" Node.toJson idx]
    | .xArrow _ _ label body below =>
      #[("label", s label)] ++ opt "body" Node.toJson body ++
      opt "below" (fun b => (nul "" Node.toJson b).1) below
  .obj (head ++ fields)

/-- A list of nodes. -/
partial def nodesToJson (ns : Array Node) : Json := .arr (ns.map Node.toJson)

end

/-- An error as the harness records it: KaTeX's class, raw message, position, length and full
message. -/
def KError.toJson (e : KError) : Json :=
  match e with
  | .parse raw _ =>
    let (pos, len) := match e.position with
      | some (p, l) => (Json.num p.toFloat, Json.num l.toFloat)
      | none => (.null, .null)
    .obj #[("kind", .str "ParseError"), ("rawMessage", .str raw), ("position", pos),
      ("length", len), ("message", .str e.message)]
  | .internal cls msg => .obj #[("kind", .str cls), ("message", .str msg)]

end LeAnTeX
