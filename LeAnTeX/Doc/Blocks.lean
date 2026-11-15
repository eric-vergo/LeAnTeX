/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Tables
import LeAnTeX.Doc.Graphics

/-!
# Blocks: theorems, user environments, equations, verbatim, accents, the title

* **`\newenvironment{name}[n][default]{begin}{end}`** (and `\renewenvironment`): the begin
  code with its arguments, the end code at `\end`, inside the environment's group.
* **`\newtheorem{name}{Name}[within]`**, **`\newtheorem{name}[shared]{Name}`**,
  `\newtheorem*` (with `amsthm`): the kernel's theorems are a trivial list whose item label is
  the bold "Name n" (with the optional note in parentheses) followed by italic text; with
  `amsthm` the head ends with a period and `\thm@headsep` (5 pt plus 1 pt minus 1 pt), the
  `definition` and `remark` styles set the text upright. **`proof`** (`amsthm`): an italic
  "Proof." head, the text, and the end mark □ at the right of the last line (`\qed`'s
  `\penalty9999 \hbox{}\nobreak\hfill\quad □`).
* **Equations**: `equation` (numbered, `\theequation` in parentheses at the right; amsmath's
  layout when `amsmath` is loaded), `equation*`, `displaymath`, `align`, `align*`, `gather`,
  `gather*`, `multline`, `multline*` laid out by the math layout's `aligned` and `gathered`
  as one displayed formula: their rows step `equation` but the row numbers are not drawn
  (TeX sets each row as a line of its own; here the display is one box). `\label` inside
  them records the number; `\nonumber` and `\notag` drop it.
* **`verbatim`** and **`\verb`**: the raw text (taken out of the source before it is read,
  `prepareVerbatim`) in the typewriter font, each line a paragraph of its own with its spaces.
* **Accents** `\'` `` \` `` `\^` `\"` `\~` `\=` `\.` `\u` `\v` `\H` `\c` `\r` `\k` and `\i`, `\j`,
  `\aa`, `\AA`, `\ae`, `\AE`, `\oe`, `\OE`, `\o`, `\O`, `\ss`, `\l`, `\L`: the composed
  character when the font has it (as LuaLaTeX's Unicode fonts give it), else built as TeX's
  `\accent` builds it (the accent centred over the letter, raised by the letter's height less
  the x-height).
* **Rules**: `\hrule` in vertical mode (0.4 pt, the width of the list), `\vrule` in a paragraph
  (0.4 pt wide), both with `width`, `height`, `depth`.
* **Lengths**: `\newlength`, `\setlength` and `\addtolength` of user lengths and of the
  layout's.
* **The title**: `\title`, `\author` (`\and` between authors), `\date` (`\today` by default:
  `Settings.today`), `\thanks`, `\maketitle` as the article class sets them without a title
  page, and `abstract`.
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-! ### User environments and theorems -/

/-- `\newenvironment` and `\renewenvironment` (`renew`). -/
def newEnvironment (at_ : Tok) (renew : Bool) : M Unit := do
  let name ← readWord at_
  let n := match ← readOptional? with
    | some ts => ((tokText ts).trimAscii.toString.toNat?).getD 0
    | none => 0
  if n > 9 then failAt at_ "You already have nine parameters"
  let default ← if n > 0 then readOptional? else pure none
  let b ← paramBody (← readArg at_) n
  let e ← readArg at_
  let exists_ := (← docSt).environments.contains name
  if !renew && exists_ then failAt at_ s!"Environment {name} already defined"
  let ed : EnvDef := { params := n, default, begin_ := b, end_ := e }
  modifyDoc fun d => { d with environments := d.environments.insert name ed }

/-- A user environment's beginning: its arguments read and its begin code put back. -/
def beginUserEnv (at_ : Tok) (e : EnvDef) : M Unit := do
  let mut args : Array (Array Tok) := #[]
  if let some d := e.default then args := args.push ((← readOptional?).getD d)
  for _ in [args.size:e.params] do args := args.push (← readArg at_)
  let body := e.begin_.foldl (init := #[]) fun acc b => match b with
    | .param k => acc ++ (args[k - 1]?.getD #[])
    | b => acc.push b
  inject at_ body

/-- `\newtheorem{name}[shared]{Name}[within]` (`star`: unnumbered). -/
def newTheorem (at_ : Tok) : M Unit := do
  let star ← readStar
  let name ← readWord at_
  let shared ← readOptional?
  let printed ← readArg at_
  let within ← readOptional?
  let d ← docSt
  let counter ← if star then pure none
    else match shared with
      | some s => pure (some (tokText s).trimAscii.toString)
      | none => do
        let w := within.map fun w => (tokText w).trimAscii.toString
        let fmt := w.map fun w => s!"\\the{w}.\\arabic\{{name}}"
        defineCounter name w fmt
        pure (some name)
  let td : TheoremDef := { name := printed, counter, style := d.theoremStyle }
  modifyDoc fun d' => { d' with theorems := d'.theorems.insert name td }

/-- A theorem's beginning (see the module docstring). -/
def beginTheorem (at_ : Tok) (th : TheoremDef) : M Unit := do
  let note ← readOptional?
  let num ← match th.counter with
    | some c => do refStepCounter at_ c; theCounter at_ c
    | none => pure ""
  let ams := (← docSt).packages.contains "amsthm"
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let sp := #[csT " " at_]
  let numT := if num.isEmpty then #[] else sp ++ textToks at_ num
  let noteT := match note with
    | some n => sp ++ (if ams then #[lb, csT "mdseries" at_] ++ textToks at_ "(" ++ n ++
        textToks at_ ")" ++ #[rb] else textToks at_ "(" ++ n ++ textToks at_ ")")
    | none => #[]
  let head := #[lb, csT "bfseries" at_] ++ th.name ++ numT ++ noteT ++
    (if ams then textToks at_ "." else #[]) ++ #[rb]
  beginList at_ id (trivial := true) (ams := ams)
  let body := if th.style == "plain" || !ams then #[csT "itshape" at_] else #[]
  let sep := if ams then #[csT "hskip" at_] ++ textToks at_ "5pt plus 1pt minus 1pt" else #[]
  inject at_ (#[csT "item" at_, Tok.char '[' 12 p, csT "hskip" at_, csT "labelsep" at_] ++
    head ++ #[Tok.char ']' 12 p] ++ sep ++ body)

/-- `proof` (with `amsthm`): an italic head, and the end mark at `\end{proof}`. -/
def beginProof (at_ : Tok) : M Unit := do
  let title ← readOptional?
  let p := at_.pos
  let t := title.getD (textToks at_ "Proof")
  beginList at_ (fun l => { l with topSep := { width := 6 * 65536, stretch := 6 * 65536 } })
    (trivial := true)
  modifyVars fun v =>
    let k : FontKey := { v.key with bold := false, shape := .upright, family := .roman }
    { v with key := k }
  inject at_ (#[csT "item" at_, Tok.char '[' 12 p, csT "hskip" at_, csT "labelsep" at_,
    Tok.char '{' 1 p, csT "itshape" at_] ++ t ++ textToks at_ "." ++
    #[Tok.char '}' 2 p, Tok.char ']' 12 p])

/-- The end mark of a proof (`\qed`): `\penalty9999`, an empty box, `\nobreak\hfill\quad` and
□. -/
def qed (at_ : Tok) : M Unit := do
  startParagraph
  flushRun
  modify fun s => { s with hlist := match s.hlist.back? with
                           | some (.glue ..) => s.hlist.pop
                           | _ => s.hlist }
  push (.penalty 9999)
  push (.box 0 0 0 0 #[])
  push (.penalty 10000)
  push (.glue { stretch := 65536, stretchOrder := 2 } 0)
  let em := (← vars).key.size
  push (.glue { width := em } 0)
  let w := texTimes em 0 50972
  let h := texTimes em 0 44237
  let r : Int := 26214
  push (.box w h 0 0 #[.glue { width := (w - 5 * r / 2) / 2 } 0, .rule r h 0,
    .box (w - 2 * r) h 0 0 #[.rule (w - 2 * r) r 0, .box 0 (h - r) 0 0 #[],
      .kern (-(w - 2 * r)) .explicit, .box (w - 2 * r) h 0 (-(h - r)) #[.rule (w - 2 * r) r 0]],
    .rule r h 0])
  let _ := at_

/-! ### Equations -/

/-- The source of an environment's body up to its `\end{name}`, as text; `\label{…}`,
`\nonumber`, `\notag` taken out of it (the labels returned). -/
def readEnvBody (at_ : Tok) (name : String) : M (String × Array String × Bool) := do
  let mut out := ""
  let mut labels := #[]
  let mut nonum := false
  let (cfg, _) ← read
  for _ in [0:cfg.maxTokens + 1] do
    match ← next? with
    | none => failAt at_ s!"\\begin\{{name}} ended by the end of the source"
    | some t =>
      match t with
      | .cs "end" _ =>
        let n ← readWord at_
        if n == name then return (out, labels, nonum)
        out := out ++ s!"\\end\{{n}}"
      | .cs "label" _ => labels := labels.push (← readWord at_)
      | .cs "nonumber" _ | .cs "notag" _ => nonum := true
      | t => out := out ++ t.text
  failAt at_ "Equation too long"

/-- An equation environment (see the module docstring). -/
def equationEnv (at_ : Tok) (name : String) : M Unit := do
  let (src, labels, nonum) ← readEnvBody at_ name
  let numbered := !name.endsWith "*" && name != "displaymath" && !nonum
  let ams := (← docSt).packages.contains "amsmath"
  let base := name.dropEnd (if name.endsWith "*" then 1 else 0) |>.toString
  let math := match base with
    | "align" | "flalign" | "alignat" => s!"\\begin\{aligned}{src}\\end\{aligned}"
    | "gather" | "multline" => s!"\\begin\{gathered}{src}\\end\{gathered}"
    | _ => src
  -- rows of a numbered alignment step the counter; only one number is drawn
  let rows := if base == "equation" || base == "displaymath" then 1
    else (src.splitOn "\\\\").length
  let mut eqno : Option HNode := none
  if numbered then
    for _ in [0:rows] do refStepCounter at_ "equation"
    let num ← theCounter at_ "equation"
    for l in labels do
      modifyDoc fun d => { d with labels := d.labels.push (l, num) }
      adjustV (.label l)
    if base == "equation" then
      let tf ← fontFor { (← vars).key with family := .roman, bold := false, shape := .upright }
      let g := tf.shape ("(" ++ num ++ ")").toList.toArray
      let (w, _, _, h, d) := measure g
      eqno := some (.box w h d 0 g)
  -- the group the environment opened ends with it
  displayFormula at_ math eqno (fullWidth := ams)
  modifyDoc fun d => { d with envs := d.envs.pop }
  endGroup at_

/-! ### Verbatim -/

/-- The hexadecimal digits of a text's UTF-8 bytes. -/
def hexOf (s : String) : String :=
  String.join (s.toUTF8.toList.map fun b =>
    let h := fun (n : Nat) => (Nat.toDigits 16 n).headD '0'
    s!"{h (b.toNat / 16)}{h (b.toNat % 16)}")

/-- The text whose UTF-8 bytes the hexadecimal digits give (invalid text: empty). -/
def unhex (s : String) : String := Id.run do
  let cs := s.toList.toArray
  let v := fun (c : Char) => if c.isDigit then c.toNat - '0'.toNat else c.toNat - 'a'.toNat + 10
  let mut bytes : ByteArray := .empty
  for i in [0:cs.size / 2] do
    bytes := bytes.push (v (cs[2 * i]?.getD '0') * 16 + v (cs[2 * i + 1]?.getD '0')).toUInt8
  return (String.fromUTF8? bytes).getD ""

/-- The source with every `verbatim` environment and `\verb` taken out and replaced by the
front end's own commands holding the raw text in hexadecimal (control sequences named by
the private-use characters U+E000 and U+E001),
so that the reader never sees their contents. Comments are kept as they
are (a `%` starts one, outside verbatim text). An error, with the character offset of the
`\begin{verbatim}` or `\verb` that is not ended, for an unterminated one. -/
def prepareVerbatim (src : String) : Except (Nat × String) String := Id.run do
  let begin_ := "\\begin{verbatim}"
  let end_ := "\\end{verbatim}"
  let cs := src.toList.toArray
  let n := cs.size
  let mut out := ""
  let mut i := 0
  for _ in [0:n + 1] do
    if i ≥ n then break
    let some c := cs[i]? | break
    if c == '%' && (i == 0 || cs[i - 1]? != some '\\') then
      -- a comment: copy to the end of the line
      let mut j := i
      for _ in [i:n] do
        if cs[j]? == some '\n' then break
        j := j + 1
      out := out ++ String.ofList (cs.extract i j).toList
      i := j
    else if c == '\\' && startsAt cs i begin_ then
      let s := i + begin_.length
      match find cs s end_ with
      | none => return .error (i, "\\begin{verbatim} not ended")
      | some e =>
        -- the text after the line break that follows \begin{verbatim}
        let s := if cs[s]? == some '\n' then s + 1 else s
        let raw := String.ofList (cs.extract s e).toList
        let raw := if raw.endsWith "\n" then (raw.dropEnd 1).toString else raw
        out := out ++ "\\\uE000{" ++ hexOf raw ++ "}"
        i := e + end_.length
    else if c == '\\' && startsAt cs i "\\verb" && !(isLetterAt cs (i + 5)) then
      let star := cs[i + 5]? == some '*'
      let d := i + 5 + (if star then 1 else 0)
      match cs[d]? with
      | none => return .error (i, "\\verb ended by the end of the source")
      | some delim =>
        let mut j := d + 1
        let mut ok := false
        for _ in [d + 1:n] do
          if cs[j]? == some '\n' then break
          if cs[j]? == some delim then ok := true; break
          j := j + 1
        if !ok then return .error (i, "\\verb ended by end of line")
        out := out ++ "\\\uE001{" ++ hexOf (String.ofList (cs.extract (d + 1) j).toList) ++
          "}"
        i := j + 1
    else
      out := out.push c
      i := i + 1
  return .ok out
where
  /-- Whether `pat` occurs at `i`. -/
  startsAt (cs : Array Char) (i : Nat) (pat : String) : Bool :=
    let p := pat.toList.toArray
    (List.range p.size).all fun k => cs[i + k]? == p[k]?
  /-- The first occurrence of `pat` at or after `i`. -/
  find (cs : Array Char) (i : Nat) (pat : String) : Option Nat := Id.run do
    for k in [i:cs.size] do
      if startsAt cs k pat then return some k
    return none
  /-- Whether a letter is at `i`. -/
  isLetterAt (cs : Array Char) (i : Nat) : Bool := (cs[i]?.map Char.isAlpha).getD false

/-- Typewriter characters with their spaces kept (each space the font's space). -/
def verbText (s : String) : M Unit := do
  modifyVars fun v =>
    let k : FontKey := { v.key with family := .mono, bold := false, shape := .upright }
    { v with key := k }
  for c in s.toList do
    if c == ' ' then addSpace (some 1000)
    else if c != '\r' then addChar c
  flushRun

/-! ### Accents -/

/-- The composed character of an accent command and a letter, if Unicode has one. -/
def composeAccent (acc : String) (c : Char) : Option Char :=
  let table : List (String × String × String) :=
    [("'", "aeiouyAEIOUYcCnNsSzZ", "áéíóúýÁÉÍÓÚÝćĆńŃśŚźŹ"),
     ("`", "aeiouAEIOU", "àèìòùÀÈÌÒÙ"),
     ("^", "aeiouAEIOUcCgGhHjJsSwWyY", "âêîôûÂÊÎÔÛĉĈĝĜĥĤĵĴŝŜŵŴŷŶ"),
     ("\"", "aeiouyAEIOUY", "äëïöüÿÄËÏÖÜŸ"),
     ("~", "anoANOiuIU", "ãñõÃÑÕĩũĨŨ"),
     ("=", "aeiouAEIOU", "āēīōūĀĒĪŌŪ"),
     (".", "czeCZEgGI", "ċżėĊŻĖġĠİ"),
     ("u", "agueAGUE", "ăğŭĕĂĞŬĔ"),
     ("v", "cdenrstzCDENRSTZ", "čďěňřšťžČĎĚŇŘŠŤŽ"),
     ("H", "ouOU", "őűŐŰ"),
     ("c", "cgklnrstCGKLNRST", "çģķļņŗşţÇĢĶĻŅŖŞŢ"),
     ("r", "auAU", "åůÅŮ"),
     ("k", "aeiuAEIU", "ąęįųĄĘĮŲ")]
  match table.find? (·.1 == acc) with
  | some (_, from_, to) =>
    let f := from_.toList
    let t := to.toList
    match f.findIdx? (· == c) with
    | some k => t[k]?
    | none => none
  | none => none

/-- The accent character an accent command draws when it is built as TeX builds it. -/
def accentChar : String → Char
  | "'" => '´' | "`" => '`' | "^" => 'ˆ' | "\"" => '¨' | "~" => '˜' | "=" => '¯' | "." => '˙'
  | "u" => '˘' | "v" => 'ˇ' | "H" => '˝' | "c" => '¸' | "r" => '˚' | "k" => '˛'
  | _ => '´'

/-- An accent command on its argument (see the module docstring). -/
def accent (at_ : Tok) (acc : String) : M Unit := do
  let arg ← readArg at_
  let base := match arg.toList.filter (!·.isSpace) with
    | [.char c _ _] => some c
    | [.cs "i" _] => some 'ı'
    | [.cs "j" _] => some 'ȷ'
    | _ => none
  let some b := base | failAt at_ s!"\\{acc} needs a single letter here"
  let tf ← fontFor (← vars).key
  match composeAccent acc (if b == 'ı' then 'i' else b) with
  | some c =>
    if tf.info.font.glyph c != 0 then addChar c; return
  | none => pure ()
  -- TeX's \accent: the accent centred over the letter and raised
  startParagraph
  let a := tf.shape #[accentChar acc]
  let l := tf.shape #[b]
  let (aw, _, _, ah, ad) := measure a
  let (lw, _, _, lh, _) := measure l
  let (_, ex) ← fontUnits
  let raise := if lh != ex then lh - ex else 0
  let delta := (lw - aw) / 2
  push (.kern delta .accent)
  push (.box aw (ah + raise) (max 0 (ad - raise)) (-raise) a)
  push (.kern (-aw - delta) .accent)
  for n in l do push n

/-- The special letters (`\ae`, `\ss`, …) and dotless `\i`, `\j`. -/
def specialLetter? : String → Option Char
  | "i" => some 'ı' | "j" => some 'ȷ' | "aa" => some 'å' | "AA" => some 'Å' | "ae" => some 'æ'
  | "AE" => some 'Æ' | "oe" => some 'œ' | "OE" => some 'Œ' | "o" => some 'ø' | "O" => some 'Ø'
  | "ss" => some 'ß' | "l" => some 'ł' | "L" => some 'Ł'
  | _ => none

/-! ### Rules and lengths -/

/-- Reads `width`, `height`, `depth` keywords of a rule. -/
def ruleSpec (at_ : Tok) (w h d : Option Int) : M (Option Int × Option Int × Option Int) := do
  let mut (w, h, d) := (w, h, d)
  for _ in [0:8] do
    if ← keyword "width" then w := some (← readDimen at_).1
    else if ← keyword "height" then h := some (← readDimen at_).1
    else if ← keyword "depth" then d := some (← readDimen at_).1
    else break
  return (w, h, d)

/-- `\addtolength{\x}{dim}` and `\setlength` of a user length. -/
def addToLength (at_ : Tok) (set_ : Bool) : M Unit := do
  let some (.cs reg _) := (← readArg at_).toList.find? (!·.isSpace)
    | failAt at_ "Missing length register"
  let g ← readGlueArg at_
  let cur ← dimenOf reg
  let d ← docSt
  if d.lengths.contains reg then
    let old := (d.lengths[reg]?).getD {}
    let ng : Glue := if set_ then g else
      { width := old.width + g.width, stretch := old.stretch + g.stretch,
        shrink := old.shrink + g.shrink }
    modifyDoc fun d => { d with lengths := d.lengths.insert reg ng }
  else
    let some c := cur | failAt at_ s!"Undefined length \\{reg}"
    let ng : Glue := if set_ then g else { g with width := c + g.width }
    let ok ← setGlue reg (if isGlueParam reg then ng else { width := ng.width })
    if !ok then failAt at_ s!"\\{reg} cannot be changed"

/-! ### The title -/

/-- `\maketitle` (see the module docstring). -/
def makeTitle (at_ : Tok) : M Unit := do
  let d ← docSt
  let p := at_.pos
  let lb := Tok.char '{' 1 p
  let rb := Tok.char '}' 2 p
  let (cfg, _) ← read
  let date := d.date.getD (textToks at_ cfg.today)
  let author := d.author
  endParagraph
  modifyDoc fun d => { d with inTitle := true, counterFormats := d.counterFormats }
  inject at_ (#[csT "leantex@null" at_, csT "vskip" at_] ++ textToks at_ "2em" ++
    #[csT "begin" at_, lb] ++ textToks at_ "center" ++ #[rb, lb, csT "LARGE" at_] ++
    d.title ++ #[csT "par" at_, rb, csT "vskip" at_] ++ textToks at_ "1.5em" ++
    #[lb, csT "large" at_, csT "lineskip" at_] ++ textToks at_ "0.5em " ++
    #[csT "begin" at_, lb] ++ textToks at_ "tabular" ++ #[rb] ++ textToks at_ "[t]" ++ #[lb] ++
    textToks at_ "c" ++ #[rb] ++ author ++ #[csT "end" at_, lb] ++ textToks at_ "tabular" ++
    #[rb, csT "par" at_, rb, csT "vskip" at_] ++ textToks at_ "1em" ++
    #[lb, csT "large" at_] ++ date ++ #[rb, csT "end" at_, lb] ++ textToks at_ "center" ++
    #[rb, csT "par" at_, csT "vskip" at_] ++ textToks at_ "1.5em" ++
    #[csT "leantex@endtitle" at_])

end LeAnTeX.Text.Typeset
