/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX
import LeAnTeXTest.JsonParse

/-!
# Corpus cases

Reading the corpora (`corpus/*.jsonl`): a case's id, formula and KaTeX settings, shared by the
test driver and the display-list dump.
-/

open LeAnTeX

/-- A corpus case: its id, the formula and the settings it is parsed with. -/
structure Case where
  /-- The case id. -/
  id : String
  /-- The formula. -/
  tex : String
  /-- The settings. -/
  settings : Settings

/-- The settings a corpus case asks for. -/
def caseSettings (j : Json) : Settings := Id.run do
  let mut s : Settings := {}
  s := { s with displayMode := ((j.get? "display").bind Json.getBool?).getD false }
  if let some (.obj kvs) := j.get? "macros" then
    s := { s with macros := kvs.filterMap fun (k, v) => v.getStr?.map (k, ·) }
  if let some st := j.get? "settings" then
    if let some v := st.get? "strict" then
      s := { s with strict := match v with
        | .bool true | .str "error" => .error
        | .bool false | .str "ignore" => .ignore
        | _ => .warn }
    if let some v := (st.get? "trust").bind Json.getBool? then s := { s with trust := v }
    if let some v := (st.get? "throwOnError").bind Json.getBool? then
      s := { s with throwOnError := v }
    if let some v := (st.get? "colorIsTextColor").bind Json.getBool? then
      s := { s with colorIsTextColor := v }
    if let some v := (st.get? "globalGroup").bind Json.getBool? then
      s := { s with globalGroup := v }
    if let some v := (st.get? "leqno").bind Json.getBool? then s := { s with leqno := v }
    if let some v := (st.get? "fleqn").bind Json.getBool? then s := { s with fleqn := v }
    if let some v := (st.get? "maxExpand").bind Json.getNum? then
      s := { s with maxExpand := v.toUInt64.toNat }
    if let some v := (st.get? "errorColor").bind Json.getStr? then
      s := { s with errorColor := v }
  return s

/-- The JSON lines of a file after its metadata line. -/
def readJsonLines (path : System.FilePath) : IO (Array Json) := do
  let lines ← IO.FS.lines path
  let mut out := #[]
  for l in lines.toList.drop 1 do
    if l.trimAscii.isEmpty then continue
    match Json.parse l with
    | .ok j => out := out.push j
    | .error e => throw (IO.userError s!"{path}: bad JSON line ({e}): {l.take 80}")
  return out
