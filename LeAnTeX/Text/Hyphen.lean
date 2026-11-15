/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Std.Data.HashMap
import LeAnTeX.Data.HyphenEnglish
import LeAnTeX.Data.HyphenEnUs

/-!
# Hyphenation

Liang's algorithm, as TeX applies it: a word's hyphenation points from a language's patterns,
unless the word is one of the language's exceptions, then cut to the hyphen minima.

* A pattern is a string of letters with a digit between some of them (`a1b`, `.ach4`; `.` marks
  the start or end of a word). Every pattern whose letters occur in the word, with the word
  written between two dots, gives its digits to the places between those letters; each place
  takes the largest digit it is given, and an odd digit allows a hyphen there.
* An exception is a word with its hyphens written in (`ta-ble`); a word that is an exception is
  hyphenated there and nowhere else.
* No hyphen is allowed within the first `left` letters or the last `right` letters
  (`\lefthyphenmin`, `\righthyphenmin`).
* Letters are compared in lower case (TeX's `\lccode`; capitals are hyphenated, as with
  `\uchyph=1`).

## Main definitions

* `Patterns`, `Patterns.ofStrings`: a language's patterns and exceptions.
* `Patterns.points`: the hyphenation points of a word.
* `Patterns.hyphenate`: the word with `-` at its points.
* `Patterns.english`: plain TeX's English patterns (`LeAnTeX.Data.HyphenEnglish`), LaTeX's
  default; `Patterns.enUsMax`: hyph-utf8's US English (`LeAnTeX.Data.HyphenEnUs`).

## Implementation notes

Patterns are kept in a hash map from their letters to their digits rather than in Liang's
packed trie: a word of `n` letters looks up at most `n · m` substrings, `m` the longest
pattern's length (9 for US English). The result does not depend on the representation.

## References

* Franklin M. Liang, *Word Hy-phen-a-tion by Com-put-er*, PhD thesis, Stanford University,
  1983 (the algorithm).
* Donald E. Knuth, *The TeXbook*, appendix H, and *TeX: The Program*, parts 40–43 (how TeX
  applies it; written from the published description).
-/

namespace LeAnTeX.Text

/-- A language's hyphenation patterns and exceptions. -/
structure Patterns where
  /-- Each pattern's letters, mapped to its digits (one more than the letters). -/
  table : Std.HashMap String (Array Nat) := {}
  /-- The most letters in a pattern. -/
  maxLen : Nat := 0
  /-- Each exception's letters, mapped to its hyphenation points. -/
  exceptions : Std.HashMap String (Array Nat) := {}

/-- The letters of a pattern and its digits: `a1b` gives `("ab", #[0, 1, 0])`. -/
def parsePattern (p : String) : String × Array Nat := Id.run do
  let mut letters := ""
  let mut digits : Array Nat := #[0]
  for c in p.toList do
    if c.isDigit then digits := digits.setIfInBounds (digits.size - 1) (c.toNat - '0'.toNat)
    else letters := letters.push c; digits := digits.push 0
  return (letters, digits)

/-- The letters of an exception and its points: `ta-ble` gives `("table", #[2])`. -/
def parseException (e : String) : String × Array Nat := Id.run do
  let mut letters := ""
  let mut pts : Array Nat := #[]
  for c in e.toList do
    if c == '-' then pts := pts.push letters.length
    else letters := letters.push c
  return (letters, pts)

namespace Patterns

/-- The patterns and exceptions written one per whitespace-separated word. -/
def ofStrings (patterns exceptions : String) : Patterns := Id.run do
  let words := fun (s : String) => (s.split Char.isWhitespace).toList.map (·.toString)
    |>.filter (!·.isEmpty)
  let mut t : Patterns := {}
  for p in words patterns do
    let (l, d) := parsePattern p
    t := { t with table := t.table.insert l d, maxLen := max t.maxLen l.length }
  for e in words exceptions do
    let (l, pts) := parseException e
    t := { t with exceptions := t.exceptions.insert l.toLower pts }
  return t

/-- The places where the patterns allow a hyphen in `w` (lower case), before cutting to the
minima: `k` for a hyphen after the `k`th letter. -/
def patternPoints (ps : Patterns) (w : String) : Array Nat := Id.run do
  let chars := (('.' :: w.toList) ++ ['.']).toArray
  let n := chars.size
  let mut vals : Array Nat := Array.replicate (n + 1) 0
  for i in [0:n] do
    let mut sub := ""
    for j in [i:min n (i + ps.maxLen)] do
      sub := sub.push (chars[j]?.getD '.')
      if let some ds := ps.table[sub]? then
        for k in [0:ds.size] do
          let v := ds[k]?.getD 0
          if v > vals[i + k]?.getD 0 then vals := vals.setIfInBounds (i + k) v
  -- place `k` of the word (after its `k`th letter) is place `k + 1` of the dotted word
  let mut out := #[]
  for k in [1:w.length] do
    if vals[k + 1]?.getD 0 % 2 == 1 then out := out.push k
  return out

/-- The hyphenation points of `word`: `k` for a hyphen after its `k`th letter, in increasing
order, each with at least `left` letters before it and `right` after it. An exception's points
replace the patterns'. -/
def points (ps : Patterns) (word : String) (left := 2) (right := 3) : Array Nat :=
  let w := word.toLower
  let raw := match ps.exceptions[w]? with
    | some pts => pts
    | none => ps.patternPoints w
  let n := word.length
  raw.filter fun k => left ≤ k && k + right ≤ n

/-- `word` with `-` at each of its hyphenation points. -/
def hyphenate (ps : Patterns) (word : String) (left := 2) (right := 3) : String := Id.run do
  let pts := ps.points word left right
  let mut out := ""
  let mut k := 0
  for c in word.toList do
    if k > 0 && pts.contains k then out := out.push '-'
    out := out.push c
    k := k + 1
  return out

/-- English as plain TeX and LaTeX hyphenate it by default: Knuth's `hyphen.tex`
(`LeAnTeX.Data.HyphenEnglish`). -/
def english : Patterns := ofStrings Data.hyphenEnglishPatterns Data.hyphenEnglishExceptions

/-- US English with Kuiken's additional patterns, TeX Live's `usenglishmax` (`hyph-en-us`,
`LeAnTeX.Data.HyphenEnUs`). -/
def enUsMax : Patterns := ofStrings Data.hyphenEnUsPatterns Data.hyphenEnUsExceptions

end Patterns

end LeAnTeX.Text
