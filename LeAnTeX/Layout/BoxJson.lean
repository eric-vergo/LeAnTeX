/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Box
import LeAnTeX.Json

/-!
# The box tree as JSON

A box tree to and from the compact JSON form that `tools/record.mjs --layout` writes for
KaTeX's own trees, so that the two can be compared and KaTeX's tree evaluated by the same code.

## Main definitions

* `Box.toJson`: the compact form (kind `k`, text `t`, classes `c`, height `h`, depth `d`,
  maxFontSize `m`, italic `i`, skew `sk`, width `w`, style `st`, attributes `at`, children
  `ch`; zero numbers and empty lists left out).
* `Box.ofJson`: a box tree from that form.

## Implementation notes

`loc` and a symbol's metric font are not part of the form (KaTeX has neither); `ofJson` leaves
them unset. A style length reads back as a length when its text is a number followed by `em`.
Both conversions recurse on the children, by well-founded recursion on the size of the tree.

## References

* KaTeX's `src/domTree.ts` (the node kinds and their fields; MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX

/-- A length as a JSON number in em. -/
def Em.toJson (x : Em) : Json := .num x.toFloat

/-- Add a number field unless it is zero. -/
private def putNum (kvs : Array (String × Json)) (key : String) (x : Em) :
    Array (String × Json) :=
  if x == 0 then kvs else kvs.push (key, x.toJson)

/-- A list of string pairs as JSON. -/
private def pairsJson (xs : Array (String × String)) : Json :=
  .arr (xs.map fun (a, b) => .arr #[.str a, .str b])

/-- An SVG child as JSON. -/
def SvgChild.toJson : SvgChild → Json
  | .path name alt =>
    .obj (#[("k", .str "path"), ("name", .str name)] ++
      (match alt with | some a => #[("alt", .str a)] | none => #[]))
  | .line attrs => .obj #[("k", .str "line"), ("at", pairsJson attrs)]

/-- A child of a box is smaller than the box. -/
theorem Box.sizeOf_lt_of_mem_children {b c : Box} (h : c ∈ b.children) :
    sizeOf c < sizeOf b := by
  have := Array.sizeOf_lt_of_mem h
  cases b
  simp only [Box.mk.sizeOf_spec] at *
  omega

/-- A value inside an array that is the value of a key of an object is smaller than the
object. -/
theorem Json.sizeOf_lt_of_mem_obj_arr {kvs : Array (String × Json)} {k : String}
    {xs : Array Json} {x : Json} (h1 : (k, Json.arr xs) ∈ kvs) (h2 : x ∈ xs) :
    sizeOf x < sizeOf (Json.obj kvs) := by
  have := Array.sizeOf_lt_of_mem h1
  have := Array.sizeOf_lt_of_mem h2
  simp only [Json.obj.sizeOf_spec, Json.arr.sizeOf_spec, Prod.mk.sizeOf_spec] at *
  omega

/-- A box tree in the compact JSON form. -/
def Box.toJson (b : Box) : Json :=
  let children := b.children.attach.map fun ⟨c, _⟩ => Box.toJson c
  let common (kvs : Array (String × Json)) : Array (String × Json) := Id.run do
    let cls := b.classes.filter (· != "")
    let mut kvs := kvs
    if !cls.isEmpty then kvs := kvs.push ("c", .arr (cls.map .str))
    kvs := putNum kvs "h" b.height
    kvs := putNum kvs "d" b.depth
    kvs := putNum kvs "m" b.maxFontSize
    if !b.style.isEmpty then
      kvs := kvs.push ("st", .arr (b.style.props.map fun (k, v) => .arr #[.str k, .str v.text]))
    if !b.attrs.isEmpty then kvs := kvs.push ("at", pairsJson b.attrs)
    return kvs
  match b.kind with
  | .symbol text _ =>
    let kvs := common #[("k", .str "sym"), ("t", .str text)]
    let kvs := putNum kvs "i" b.italicOr0
    let kvs := putNum kvs "sk" b.skew
    .obj (putNum kvs "w" (b.width.getD 0))
  | .svg ch => .obj #[("k", .str "svg"), ("at", pairsJson b.attrs),
      ("ch", .arr (ch.map SvgChild.toJson))]
  | .fragment =>
    let kvs := putNum #[("k", .str "frag")] "h" b.height
    let kvs := putNum kvs "d" b.depth
    let kvs := putNum kvs "m" b.maxFontSize
    .obj (kvs.push ("ch", .arr children))
  | .img src alt => .obj (common #[("k", .str "img"), ("src", .str src), ("alt", .str alt)])
  | .span | .anchor =>
    let kvs := common #[("k", .str (if b.kind == .anchor then "a" else "span"))]
    let kvs := match b.width with | some w => kvs.push ("w", w.toJson) | none => kvs
    let kvs := match b.italic with | some i => kvs.push ("i", i.toJson) | none => kvs
    .obj (if b.children.isEmpty then kvs else kvs.push ("ch", .arr children))
termination_by b
decreasing_by exact Box.sizeOf_lt_of_mem_children ‹_›

/-- A JSON number field as a length (zero when absent). -/
private def numField (j : Json) (key : String) : Em :=
  match (j.get? key).bind Json.getNum? with
  | some x => Em.ofFloat x
  | none => 0

/-- A list of string pairs from JSON. -/
private def pairsOf (j : Option Json) : Array (String × String) :=
  match j with
  | some (.arr xs) => xs.filterMap fun p => match p with
    | .arr #[.str a, .str b] => some (a, b)
    | _ => none
  | _ => #[]

/-- A box tree from the compact JSON form. -/
def Box.ofJson (j : Json) : Box :=
  let kind := ((j.get? "k").bind Json.getStr?).getD "span"
  let classes := match j.get? "c" with
    | some (.arr xs) => xs.filterMap Json.getStr?
    | _ => #[]
  let style : Css := ⟨(pairsOf (j.get? "st")).map fun (k, v) => (k, CssValue.ofText v)⟩
  -- the children, from the first `ch` key, laid out in turn
  let children : Array Box := match j with
    | .obj kvs =>
      match (kvs.attach.find? fun ⟨(k, _), _⟩ => k == "ch") with
      | some ⟨(k, .arr xs), h1⟩ => xs.attach.map fun ⟨x, h2⟩ =>
        have : sizeOf x < sizeOf (Json.obj kvs) := Json.sizeOf_lt_of_mem_obj_arr h1 h2
        Box.ofJson x
      | _ => #[]
    | _ => #[]
  let svgChildren := match j.get? "ch" with
    | some (.arr xs) => xs
    | _ => #[]
  let base : Box := { classes, style, attrs := pairsOf (j.get? "at"),
                      height := numField j "h", depth := numField j "d",
                      maxFontSize := numField j "m" }
  match kind with
  | "sym" =>
    { base with kind := .symbol (((j.get? "t").bind Json.getStr?).getD "") "",
                italic := some (numField j "i"), skew := numField j "sk",
                width := some (numField j "w") }
  | "svg" =>
    let ch := svgChildren.filterMap fun c =>
      match (c.get? "k").bind Json.getStr? with
      | some "path" => some (.path (((c.get? "name").bind Json.getStr?).getD "")
          ((c.get? "alt").bind Json.getStr?))
      | some "line" => some (.line (pairsOf (c.get? "at")))
      | _ => none
    { base with kind := .svg ch }
  | "frag" => { base with kind := .fragment, children }
  | "img" =>
    { base with kind := .img (((j.get? "src").bind Json.getStr?).getD "")
                  (((j.get? "alt").bind Json.getStr?).getD "") }
  | k =>
    { base with kind := if k == "a" then .anchor else .span,
                children,
                width := ((j.get? "w").bind Json.getNum?).map Em.ofFloat,
                italic := ((j.get? "i").bind Json.getNum?).map Em.ofFloat }

termination_by sizeOf j
decreasing_by all_goals assumption

end LeAnTeX
