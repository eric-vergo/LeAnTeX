/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Layout.Em

/-!
# Escaping and numbers for the back ends

Everything the SVG and HTML back ends write that comes from TeX source (text, the formula's
source in titles and alternative text, colour names) is untrusted: it is escaped, or checked
against a strict form and dropped otherwise. Numbers are written from integers, so the output
is the same on every machine.

* **Escaping** (`escape`): `<`, `>`, `&`, `"` and `'` become the entities `&lt;`, `&gt;`,
  `&amp;`, `&quot;` and `&#39;`; characters XML cannot carry (control characters other than
  tab, line feed and carriage return, `U+FFFE`, `U+FFFF`) are dropped. One function serves text
  and attribute values (quotes are escaped in both). `LeAnTeX.Backend.Proofs` proves that the
  result has no `<`, `>`, `"` or `'`, and that decoding the five entities gives the input back
  less the dropped characters (so every `&` written starts an entity).
* **Colours** (`cssColor?`): `#` and 3, 4, 6 or 8 hexadecimal digits, or a name of ASCII
  letters (at most 32); anything else is no colour, so the item takes the surrounding colour,
  as a browser does with a colour it cannot read.
* **Numbers** (`fixed`, `ptText`): a decimal with at most a given number of places, rounded
  half away from zero, without trailing zeros, without an exponent, `0` rather than `-0`.

## Main definitions

* `xmlChar`, `escapeChar`, `escapeList`, `escape`, `unescapeList`.
* `cssColor?`.
* `fixed`, `ptText`, `bpText`, `spOf`.
* `terminalUnsafe`, `terminalText`: text from a source made safe to print on a terminal.
-/

namespace LeAnTeX.Backend

/-- Whether XML 1.0 can carry the character (its `Char` production). -/
def xmlChar (c : Char) : Bool :=
  let n := c.toNat
  n == 0x9 || n == 0xA || n == 0xD || (0x20 ≤ n && n ≤ 0xD7FF) || (0xE000 ≤ n && n ≤ 0xFFFD) ||
    0x10000 ≤ n

/-- One character escaped: the five special characters as entities, a character XML cannot
carry dropped, any other kept. -/
def escapeChar (c : Char) : List Char :=
  match c with
  | '<' => ['&', 'l', 't', ';']
  | '>' => ['&', 'g', 't', ';']
  | '&' => ['&', 'a', 'm', 'p', ';']
  | '"' => ['&', 'q', 'u', 'o', 't', ';']
  | '\'' => ['&', '#', '3', '9', ';']
  | c => if xmlChar c then [c] else []

/-- A list of characters escaped, character by character. -/
def escapeList : List Char → List Char
  | [] => []
  | c :: cs => escapeChar c ++ escapeList cs

/-- A string escaped for XML and HTML text and attribute values (see the module docstring). -/
def escape (s : String) : String := String.ofList (escapeList s.toList)

/-- The five entities `escape` writes decoded; everything else is kept. The inverse of
`escapeList` on characters XML can carry (`LeAnTeX.Backend.unescape_escape`). -/
def unescapeList : List Char → List Char
  | [] => []
  | '&' :: 'l' :: 't' :: ';' :: r => '<' :: unescapeList r
  | '&' :: 'g' :: 't' :: ';' :: r => '>' :: unescapeList r
  | '&' :: 'a' :: 'm' :: 'p' :: ';' :: r => '&' :: unescapeList r
  | '&' :: 'q' :: 'u' :: 'o' :: 't' :: ';' :: r => '"' :: unescapeList r
  | '&' :: '#' :: '3' :: '9' :: ';' :: r => '\'' :: unescapeList r
  | c :: r => c :: unescapeList r

/-- Whether a character is an ASCII hexadecimal digit. -/
def hexDigit (c : Char) : Bool :=
  ('0' ≤ c && c ≤ '9') || ('a' ≤ c && c ≤ 'f') || ('A' ≤ c && c ≤ 'F')

/-- Whether a character is an ASCII letter. -/
def asciiLetter (c : Char) : Bool := ('a' ≤ c && c ≤ 'z') || ('A' ≤ c && c ≤ 'Z')

/-- A colour from TeX source as CSS can take it: `#` and 3, 4, 6 or 8 hexadecimal digits, or a
name of 1 to 32 ASCII letters; `none` for anything else. -/
def cssColor? (s : String) : Option String :=
  match s.toList with
  | '#' :: ds => if [3, 4, 6, 8].contains ds.length && ds.all hexDigit then some s else none
  | cs => if 0 < cs.length && cs.length ≤ 32 && cs.all asciiLetter then some s else none

/-- `n / 10 ^ places` as a decimal with at most `places` places and no trailing zeros. -/
def decimalOf (n : Int) (places : Nat) : String :=
  let a := n.natAbs
  let p := 10 ^ places
  let frac := toString (a % p)
  let frac := String.ofList (List.replicate (places - frac.length) '0') ++ frac
  let frac := String.ofList (frac.toList.reverse.dropWhile (· == '0')).reverse
  (if n < 0 then "-" else "") ++ toString (a / p) ++ (if frac.isEmpty then "" else "." ++ frac)

/-- `num / den` rounded half away from zero to `places` decimal places, as a decimal (`0` for a
zero denominator). -/
def fixed (num den : Int) (places : Nat) : String :=
  if den == 0 then "0" else decimalOf (Em.roundDiv (num * 10 ^ places) den) places

/-- A length in scaled points as points with at most three decimals (`12.5`, `-0.004`). -/
def ptText (sp : Int) : String := fixed sp 65536 3

/-- A length in scaled points (TeX's points, 1/72.27 inch) as the points of CSS and SVG (1/72
inch, PostScript's big points) with at most three decimals: what a page writes in `pt` units,
so that ten TeX points are as long on a screen or in a PDF viewer as in TeX's own output. -/
def bpText (sp : Int) : String := fixed (sp * 7200) (7227 * 65536) 3

/-- A display-list length in scaled points, for a display list whose em is `em` sp. -/
def spOf (em : Int) (e : Em) : Int := Em.roundDiv (e.raw * em) Em.unit

/-! ### Text for a terminal -/

/-- Whether a character must not reach a terminal or a log as it is: the C0 and C1 control
characters and `U+007F`; the line and paragraph separators `U+2028`, `U+2029` (and `U+0085`, a
C1 control); the bidirectional formatting characters (`U+061C`, `U+200E`, `U+200F`, `U+202A` to
`U+202E`, `U+2066` to `U+2069`); and the invisible formatting characters `U+00AD`, `U+034F`,
`U+115F`, `U+1160`, `U+17B4`, `U+17B5`, `U+180B` to `U+180F`, `U+200B` to `U+200D`, `U+2060` to
`U+2064`, `U+3164`, `U+FE00` to `U+FE0F`, `U+FEFF`, `U+FFA0` and `U+FFF9` to `U+FFFB`. Each can
start a terminal escape, end a line, reorder or hide text. -/
def terminalUnsafe (c : Char) : Bool :=
  let v := c.val
  v < 0x20 || (0x7F ≤ v && v ≤ 0x9F) || v == 0xAD || v == 0x34F || v == 0x61C || v == 0x115F ||
    v == 0x1160 || v == 0x17B4 || v == 0x17B5 || (0x180B ≤ v && v ≤ 0x180F) ||
    (0x200B ≤ v && v ≤ 0x200F) || (0x2028 ≤ v && v ≤ 0x202E) || (0x2060 ≤ v && v ≤ 0x2064) ||
    (0x2066 ≤ v && v ≤ 0x2069) || v == 0x3164 || (0xFE00 ≤ v && v ≤ 0xFE0F) || v == 0xFEFF ||
    v == 0xFFA0 || (0xFFF9 ≤ v && v ≤ 0xFFFB)

/-- The text with every `terminalUnsafe` character and the backslash written as escapes
(`\\n`, `\\t`, `\\\\`, `\\u{..}` in hexadecimal): what the command-line programs print for any
string that comes from their input (messages that quote the source, file names, warnings), so
that the source cannot forge or hide a line of their output. -/
def terminalText (s : String) : String :=
  s.foldl (init := "") fun out c =>
    if c == '\n' then out ++ "\\n" else if c == '\t' then out ++ "\\t"
    else if c == '\\' then out ++ "\\\\"
    else if terminalUnsafe c then
      out ++ "\\u{" ++ String.ofList (Nat.toDigits 16 c.val.toNat) ++ "}"
    else out.push c

end LeAnTeX.Backend
