/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.OpenType.Tables
import Std.Data.HashMap

/-!
# OpenType layout: ligatures and pair kerning

The parts of `GSUB` and `GPOS` that set Latin text: the script, feature and lookup lists, and
the lookups of single and ligature substitution (`GSUB` types 1 and 4) and pair adjustment
(`GPOS` type 2, both formats), reached directly or through extension lookups (`GSUB` 7,
`GPOS` 9). They are read once, when the font is read, into sorted arrays; applying them costs a
binary search per glyph.

## Main definitions

* `Coverage`, `ClassDef`: their two formats each.
* `LayoutTable.read`: the script, feature and lookup lists of `GSUB` or `GPOS`.
* `LayoutTable.lookupsFor`: the lookups of a feature under a script's default language system.
* `Gsub`, `Gsub.apply`: substitution lookups applied to a run of glyphs.
* `Gpos`, `Gpos.kerning`: the horizontal kerning of a pair of glyphs.

## Implementation notes

Lookup flags are not honoured (marks are not skipped), contextual lookups are not applied, and of
a pair adjustment only the first glyph's `xAdvance` is used: what horizontal kerning of Latin
text needs, and what TeX's OpenType loader applies for the `kern` feature in base mode.

## References

* The OpenType specification 1.9.1, "OpenType Layout common table formats", "GSUB", "GPOS".
-/

namespace LeAnTeX.OpenType

/-- A coverage table: the glyphs a subtable applies to, each with its coverage index. -/
inductive Coverage where
  /-- Format 1: the glyphs, ascending; a glyph's index is its position. -/
  | list (glyphs : Array Nat)
  /-- Format 2: ranges `(start, end, startIndex)`, ascending. -/
  | ranges (rs : Array (Nat × Nat × Nat))
  deriving Inhabited

/-- Reads a coverage table. -/
def Coverage.read (s : Slice) : Result Coverage := do
  match ← s.u16 0 with
  | 1 =>
    let n ← s.u16 2
    s.need 4 (2 * n)
    let mut gs := Array.mkEmpty n
    for i in [0:n] do gs := gs.push (← s.u16 (4 + 2 * i))
    return .list gs
  | 2 =>
    let n ← s.u16 2
    s.need 4 (6 * n)
    let mut rs := Array.mkEmpty n
    for i in [0:n] do
      let r := 4 + 6 * i
      rs := rs.push (← s.u16 r, ← s.u16 (r + 2), ← s.u16 (r + 4))
    return .ranges rs
  | f => s.fail s!"coverage format {f}"

/-- The coverage index of glyph `g`, if covered. -/
def Coverage.index? (c : Coverage) (g : Nat) : Option Nat :=
  match c with
  | .list gs =>
    let i := lowerBound gs id g
    if gs[i]? == some g then some i else none
  | .ranges rs =>
    let i := lowerBound rs (·.2.1) g
    match rs[i]? with
    | some (st, e, idx) => if st ≤ g && g ≤ e then some (idx + (g - st)) else none
    | none => none

/-- A class definition table: the class of each glyph (0 for glyphs it does not list). -/
inductive ClassDef where
  /-- Format 1: classes of consecutive glyphs from `start`. -/
  | array (start : Nat) (classes : Array Nat)
  /-- Format 2: ranges `(start, end, class)`, ascending. -/
  | ranges (rs : Array (Nat × Nat × Nat))
  deriving Inhabited

/-- Reads a class definition table. -/
def ClassDef.read (s : Slice) : Result ClassDef := do
  match ← s.u16 0 with
  | 1 =>
    let start ← s.u16 2
    let n ← s.u16 4
    s.need 6 (2 * n)
    let mut cs := Array.mkEmpty n
    for i in [0:n] do cs := cs.push (← s.u16 (6 + 2 * i))
    return .array start cs
  | 2 =>
    let n ← s.u16 2
    s.need 4 (6 * n)
    let mut rs := Array.mkEmpty n
    for i in [0:n] do
      let r := 4 + 6 * i
      rs := rs.push (← s.u16 r, ← s.u16 (r + 2), ← s.u16 (r + 4))
    return .ranges rs
  | f => s.fail s!"class definition format {f}"

/-- The class of glyph `g`. -/
def ClassDef.classOf (c : ClassDef) (g : Nat) : Nat :=
  match c with
  | .array start cs => if start ≤ g then cs[g - start]?.getD 0 else 0
  | .ranges rs =>
    let i := lowerBound rs (·.2.1) g
    match rs[i]? with
    | some (st, e, k) => if st ≤ g && g ≤ e then k else 0
    | none => 0

/-- A lookup of the lookup list: its type (extension lookups resolved) and the windows of its
subtables. -/
structure Lookup where
  /-- The lookup type. -/
  type : Nat
  /-- The lookup flags (read, not applied). -/
  flags : Nat
  /-- The subtables. -/
  subtables : Array Slice

/-- The script, feature and lookup lists of `GSUB` or `GPOS`. -/
structure LayoutTable where
  /-- Scripts: tag and the feature indices of its default language system. -/
  scripts : Array (String × Array Nat)
  /-- Features: tag and lookup indices. -/
  features : Array (String × Array Nat)
  /-- The lookups. -/
  lookups : Array Lookup

/-- `n` 16-bit values from `off`. -/
private def u16s (s : Slice) (off n : Nat) : Result (Array Nat) := do
  s.need off (2 * n)
  let mut out := Array.mkEmpty n
  for i in [0:n] do out := out.push (← s.u16 (off + 2 * i))
  return out

/-- Reads the lists of a `GSUB` (`extension` 7) or `GPOS` (`extension` 9) table. -/
def LayoutTable.read (s : Slice) (extension : Nat) : Result LayoutTable := do
  let sl ← s.drop (← s.u16 4)
  let fl ← s.drop (← s.u16 6)
  let ll ← s.drop (← s.u16 8)
  let mut scripts := #[]
  let ns ← sl.u16 0
  sl.need 2 (6 * ns)
  for i in [0:ns] do
    let tag ← sl.tag (2 + 6 * i)
    let sc ← sl.drop (← sl.u16 (6 + 6 * i))
    let dflt ← sc.u16 0
    if dflt == 0 then scripts := scripts.push (tag, #[])
    else
      let ls ← sc.drop dflt
      let req ← ls.u16 2
      let fs ← u16s ls 6 (← ls.u16 4)
      scripts := scripts.push (tag, if req == 0xFFFF then fs else #[req] ++ fs)
  let mut features := #[]
  let nf ← fl.u16 0
  fl.need 2 (6 * nf)
  for i in [0:nf] do
    let tag ← fl.tag (2 + 6 * i)
    let f ← fl.drop (← fl.u16 (6 + 6 * i))
    features := features.push (tag, ← u16s f 4 (← f.u16 2))
  let mut lookups := #[]
  let nl ← ll.u16 0
  for off in ← u16s ll 2 nl do
    let l ← ll.drop off
    let type ← l.u16 0
    let flags ← l.u16 2
    let mut subs := #[]
    let mut realType := type
    for so in ← u16s l 6 (← l.u16 4) do
      let st ← l.drop so
      if type == extension then
        let t ← st.u16 2
        if t == extension then st.fail "extension of an extension"
        realType := t
        subs := subs.push (← st.drop (← st.u32 4))
      else subs := subs.push st
    lookups := lookups.push ⟨realType, flags, subs⟩
  return ⟨scripts, features, lookups⟩

/-- The lookup indices of feature `feature` under the default language system of `script`
(`DFLT` if the font has no such script, else its first script), ascending: the order lookups
are applied in. -/
def LayoutTable.lookupsFor (t : LayoutTable) (feature : String) (script : String := "latn") :
    Array Nat :=
  let sc := (t.scripts.find? (·.1 == script)).orElse fun _ =>
    (t.scripts.find? (·.1 == "DFLT")).orElse fun _ => t.scripts[0]?
  match sc with
  | none => #[]
  | some (_, fis) =>
    let ls := fis.foldl (init := #[]) fun acc fi =>
      match t.features[fi]? with
      | some (tag, ls) => if tag == feature then acc ++ ls else acc
      | none => acc
    (ls.qsort (· < ·)).toList.eraseDups.toArray.filter (· < t.lookups.size)

/-- A substitution subtable. -/
inductive Subst where
  /-- Single substitution: a covered glyph becomes `(g + delta) % 65536` (format 1). -/
  | delta (cov : Coverage) (delta : Nat)
  /-- Single substitution: covered glyph `i` becomes `glyphs[i]` (format 2). -/
  | single (cov : Coverage) (glyphs : Array Nat)
  /-- Ligature substitution: for covered glyph `i`, the ligatures `sets[i]` in order of
  preference, each its glyph and the components after the first. -/
  | ligature (cov : Coverage) (sets : Array (Array (Nat × Array Nat)))
  deriving Inhabited

/-- The number of entries of a coverage table, a measure of the work of reading it. -/
def Coverage.size : Coverage → Nat
  | .list gs => gs.size
  | .ranges rs => rs.size

/-- The number of entries of a class definition table. -/
def ClassDef.size : ClassDef → Nat
  | .array _ cs => cs.size
  | .ranges rs => rs.size

/-- The work a font's layout tables may cost to read: `layoutWorkFactor` entries per byte of
the table (subtables shared by several lookups are read once). Real fonts stay far below it;
a table whose subtables overlap to multiply its apparent content is an error. -/
def layoutWorkFactor : Nat := 8

/-- Reads a `GSUB` subtable of type 1 or 4; other types give `none`. Reading more than `limit`
ligatures is an error (ligature sets shared between first glyphs could otherwise multiply a
small table into a vast one). -/
def Subst.read (type : Nat) (s : Slice) (limit : Nat) : Result (Option Subst) := do
  match type, ← s.u16 0 with
  | 1, 1 => return some (.delta (← Coverage.read (← s.drop (← s.u16 2))) (← s.u16 4))
  | 1, 2 =>
    return some (.single (← Coverage.read (← s.drop (← s.u16 2))) (← u16s s 6 (← s.u16 4)))
  | 4, 1 =>
    let cov ← Coverage.read (← s.drop (← s.u16 2))
    let mut sets := #[]
    let mut count := 0
    for so in ← u16s s 6 (← s.u16 4) do
      let set ← s.drop so
      let mut ligs := #[]
      let offs ← u16s set 2 (← set.u16 0)
      count := count + offs.size
      if count > limit then s.fail "more ligatures than the table can hold"
      for lo in offs do
        let l ← set.drop lo
        let n ← l.u16 2
        if n == 0 then l.fail "ligature without components"
        ligs := ligs.push (← l.u16 0, ← u16s l 4 (n - 1))
      sets := sets.push ligs
    return some (.ligature cov sets)
  | 1, f | 4, f => s.fail s!"GSUB type {type} format {f}"
  | _, _ => return none

/-- The substitution lookups of a font, read. -/
structure Gsub where
  /-- The lists. -/
  table : LayoutTable
  /-- Each lookup's subtables of the types read (others left out). -/
  substs : Array (Array Subst)

/-- The number of entries of a substitution subtable. -/
def Subst.size : Subst → Nat
  | .delta cov _ => cov.size
  | .single cov gs => cov.size + gs.size
  | .ligature cov sets => cov.size + sets.foldl (fun a s => a + s.foldl
      (fun b l => b + 1 + l.2.size) 0) 0

/-- Reads `GSUB`. A subtable reached from several lookups is read once. -/
def Gsub.read (s : Slice) : Result Gsub := do
  let t ← LayoutTable.read s 7
  let mut substs := #[]
  let mut seen : Std.HashMap Nat (Option Subst) := {}
  let mut work := 0
  for l in t.lookups do
    let mut subs := #[]
    for st in l.subtables do
      let x ← match seen.get? (l.type * 2 ^ 40 + st.start) with
        | some x => pure x
        | none => do
          let x ← Subst.read l.type st (layoutWorkFactor * s.size + 65536)
          work := work + 1 + (x.map Subst.size).getD 0
          if work > layoutWorkFactor * s.size + 65536 then
            s.fail "subtables larger than the table can hold"
          seen := seen.insert (l.type * 2 ^ 40 + st.start) x
          pure x
      if let some x := x then subs := subs.push x
    substs := substs.push subs
  return ⟨t, substs⟩

/-- Applies one subtable at position `i`: the replacement and how many glyphs it consumes. -/
private def Subst.at? (x : Subst) (gs : Array Nat) (i : Nat) : Option (Nat × Nat) := do
  let g ← gs[i]?
  match x with
  | .delta cov d => let _ ← cov.index? g; some ((g + d) % 65536, 1)
  | .single cov out => some (← out[← cov.index? g]?, 1)
  | .ligature cov sets =>
    let set ← sets[← cov.index? g]?
    let hit := set.find? fun (_, rest) =>
      rest.size + i < gs.size && (List.range rest.size).all fun j => gs[i + 1 + j]? == rest[j]?
    hit.map fun (lig, rest) => (lig, rest.size + 1)

/-- The glyphs after applying the lookups of `features` (for `script`) in lookup-list order,
each lookup across the whole run before the next: at each position the first subtable that
applies replaces the glyph, or the glyphs it joins. -/
def Gsub.apply (g : Gsub) (features : List String) (gs : Array Nat)
    (script : String := "latn") : Array Nat := Id.run do
  let idx := features.foldl (fun acc f => acc ++ g.table.lookupsFor f script) #[]
  let idx := (idx.qsort (· < ·)).toList.eraseDups
  let mut cur := gs
  for li in idx do
    let subs := g.substs[li]?.getD #[]
    let mut out := Array.mkEmpty cur.size
    let mut i := 0
    -- Each step consumes at least one glyph.
    for _ in [0:cur.size] do
      if i < cur.size then
        match subs.findSome? (·.at? cur i) with
        | some (r, n) => out := out.push r; i := i + n
        | none => out := out.push (cur[i]?.getD 0); i := i + 1
    cur := out
  return cur

/-- A pair-adjustment subtable, reduced to the first glyph's `xAdvance`. -/
inductive PairPos where
  /-- Format 1: for covered first glyph `i`, `(second, xAdvance)` ascending by second glyph. -/
  | pairs (cov : Coverage) (sets : Array (Array (Nat × Int)))
  /-- Format 2: `values[c1 * class2Count + c2]` for the glyphs' classes. -/
  | classes (cov : Coverage) (cd1 cd2 : ClassDef) (class2Count : Nat) (values : Array Int)
  deriving Inhabited

/-- The size in bytes of a value record of the format, and the offset of its `xAdvance` (if the
format has one). -/
def valueRecordLayout (fmt : Nat) : Nat × Option Nat :=
  let bit := fun (k : Nat) => (fmt >>> k) &&& 1
  let size := 2 * (List.range 8).foldl (fun a k => a + bit k) 0
  let xAdv := if bit 2 == 1 then some (2 * (bit 0 + bit 1)) else none
  (size, xAdv)

/-- Reads a `GPOS` type 2 subtable; reading more than `limit` pairs is an error (pair sets
shared between first glyphs could otherwise multiply a small table into a vast one). -/
def PairPos.read (s : Slice) (limit : Nat) : Result PairPos := do
  let fmt ← s.u16 0
  let cov ← Coverage.read (← s.drop (← s.u16 2))
  let (size1, xa) := valueRecordLayout (← s.u16 4)
  let (size2, _) := valueRecordLayout (← s.u16 6)
  let xAt := fun (r : Slice) (off : Nat) => match xa with
    | some o => r.i16 (off + o)
    | none => pure 0
  match fmt with
  | 1 =>
    let mut sets := #[]
    let mut count := 0
    for so in ← u16s s 10 (← s.u16 8) do
      let ps ← s.drop so
      let n ← ps.u16 0
      count := count + n
      if count > limit then s.fail "more pairs than the table can hold"
      let rec_ := 2 + size1 + size2
      ps.need 2 (rec_ * n)
      let mut set := Array.mkEmpty n
      for i in [0:n] do
        let r := 2 + rec_ * i
        set := set.push (← ps.u16 r, ← xAt ps (r + 2))
      sets := sets.push (set.qsort (fun a b => a.1 < b.1))
    return .pairs cov sets
  | 2 =>
    let cd1 ← ClassDef.read (← s.drop (← s.u16 8))
    let cd2 ← ClassDef.read (← s.drop (← s.u16 10))
    let c1 ← s.u16 12
    let c2 ← s.u16 14
    let rec_ := size1 + size2
    s.need 16 (c1 * c2 * rec_)
    -- Without an xAdvance every value is 0; the matrix is then not stored.
    let mut vals := #[]
    if xa.isSome then
      for i in [0:c1 * c2] do vals := vals.push (← xAt s (16 + rec_ * i))
    return .classes cov cd1 cd2 c2 vals
  | f => s.fail s!"pair adjustment format {f}"

/-- The kerning of the pair under the subtable, if the subtable applies to it. -/
def PairPos.get? (p : PairPos) (l r : Nat) : Option Int := do
  match p with
  | .pairs cov sets =>
    let set ← sets[← cov.index? l]?
    let i := lowerBound set (·.1) r
    match set[i]? with
    | some (g, v) => if g == r then some v else none
    | none => none
  | .classes cov cd1 cd2 c2 vals =>
    let _ ← cov.index? l
    some (vals[cd1.classOf l * c2 + cd2.classOf r]?.getD 0)

/-- The positioning lookups of a font, read. -/
structure Gpos where
  /-- The lists. -/
  table : LayoutTable
  /-- Each lookup's pair-adjustment subtables (other types left out). -/
  pairs : Array (Array PairPos)

/-- The number of entries of a pair-adjustment subtable. -/
def PairPos.size : PairPos → Nat
  | .pairs cov sets => cov.size + sets.foldl (fun a s => a + s.size) 0
  | .classes cov cd1 cd2 _ vals => cov.size + cd1.size + cd2.size + vals.size

/-- Reads `GPOS`. A subtable reached from several lookups is read once. -/
def Gpos.read (s : Slice) : Result Gpos := do
  let t ← LayoutTable.read s 9
  let mut pairs := #[]
  let mut seen : Std.HashMap Nat PairPos := {}
  let mut work := 0
  for l in t.lookups do
    let mut subs := #[]
    if l.type == 2 then
      for st in l.subtables do
        match seen.get? st.start with
        | some p => subs := subs.push p
        | none =>
          let p ← PairPos.read st (layoutWorkFactor * s.size + 65536)
          work := work + 1 + p.size
          if work > layoutWorkFactor * s.size + 65536 then
            s.fail "subtables larger than the table can hold"
          seen := seen.insert st.start p
          subs := subs.push p
    pairs := pairs.push subs
  return ⟨t, pairs⟩

/-- The horizontal kerning of the pair under the `kern` feature (for `script`), in font units:
the sum over its lookups of the first subtable of each that applies. -/
def Gpos.kerning (g : Gpos) (l r : Nat) (script : String := "latn") : Int :=
  (g.table.lookupsFor "kern" script).foldl (init := 0) fun acc li =>
    acc + (((g.pairs[li]?.getD #[]).findSome? (·.get? l r)).getD 0)

end LeAnTeX.OpenType
