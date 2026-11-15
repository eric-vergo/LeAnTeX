/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.State

/-!
# The article class

The parameters of LaTeX's `article` class for its size options (`10pt`, `11pt`, `12pt`) and
paper sizes (`letterpaper`, `a4paper`), one-sided, one column: the page layout, the size
commands, the list levels, the display skips, footnotes, floats and headings. The values are
those LuaLaTeX gives on this setup (`fixtures/doc/class/params-*.txt`, recorded by
`tools/doc-reference/params.tex`; `lake test` compares them), in sp.

## Main definitions

* `ClassParams`, `classParams`: the table for an option set.
* `SectionSpec`, `sectionSpec`: the headings `\section` … `\subparagraph`.
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- Points to sp, from a value in thousandths of a point (rounded as TeX's `scan_dimen` rounds
the decimal: to the nearest sp of the fraction). -/
def ptm (thousandths : Int) : Int :=
  let whole := thousandths / 1000
  let frac := thousandths % 1000
  whole * 65536 + (frac * 65536 * 2 + 1000) / 2000

/-- Glue from widths in thousandths of a point. -/
def glueM (w s sh : Int) : Glue := { width := ptm w, stretch := ptm s, shrink := ptm sh }

/-- A size command's font size and `\baselineskip` (sp). -/
structure SizeSpec where
  /-- The command (`tiny` … `Huge`). -/
  name : String
  /-- The font size. -/
  size : Int
  /-- `\baselineskip`. -/
  baseline : Int
  deriving Inhabited, Repr

/-- The class's parameters for one option set. -/
structure ClassParams where
  /-- `\paperwidth`. -/
  paperWidth : Int
  /-- `\paperheight`. -/
  paperHeight : Int
  /-- `\textwidth`. -/
  textWidth : Int
  /-- `\textheight`. -/
  textHeight : Int
  /-- `\oddsidemargin`. -/
  oddSideMargin : Int
  /-- `\topmargin`. -/
  topMargin : Int
  /-- `\headheight`. -/
  headHeight : Int
  /-- `\headsep`. -/
  headSep : Int
  /-- `\footskip`. -/
  footSkip : Int
  /-- `\topskip`. -/
  topSkip : Int
  /-- `\maxdepth`. -/
  maxDepth : Int
  /-- `\parindent`. -/
  parIndent : Int
  /-- The size commands. -/
  sizes : Array SizeSpec
  /-- `\abovedisplayskip` and `\belowdisplayskip`. -/
  displaySkip : Glue
  /-- `\belowdisplayshortskip`. -/
  belowShortSkip : Glue
  /-- `\footnotesep`. -/
  footnoteSep : Int
  /-- `\skip\footins`. -/
  footinsSkip : Glue
  /-- `\floatsep`. -/
  floatSep : Glue
  /-- `\textfloatsep`. -/
  textFloatSep : Glue
  /-- `\intextsep`. -/
  inTextSep : Glue
  /-- `\@fpsep`. -/
  fpSep : Glue
  /-- The list levels 1 to 4: `\topsep`, `\partopsep`, `\itemsep`, `\parsep`,
  `\leftmargin`. -/
  lists : Array ListLevel
  /-- `\leftmarginv` and `\leftmarginvi`. -/
  leftMarginDeep : Int
  /-- `\labelsep`. -/
  labelSep : Int
  /-- `\marginparwidth`. -/
  marginparWidth : Int
  /-- What `\small` and `\footnotesize` set besides the font: their `\@listi` (`\topsep`,
  `\itemsep`, `\parsep`) and their display skips (`\abovedisplayskip` and
  `\belowdisplayskip`, `\abovedisplayshortskip`, `\belowdisplayshortskip`). -/
  sizeSkips : Array (String × (Glue × Glue × Glue) × (Glue × Glue × Glue)) := #[]
  deriving Inhabited

/-- The ten-point sizes. -/
def sizes10 : Array SizeSpec :=
  #[⟨"tiny", ptm 5000, ptm 6000⟩, ⟨"scriptsize", ptm 7000, ptm 8000⟩,
    ⟨"footnotesize", ptm 8000, ptm 9500⟩, ⟨"small", ptm 9000, ptm 11000⟩,
    ⟨"normalsize", ptm 10000, ptm 12000⟩, ⟨"large", ptm 12000, ptm 14000⟩,
    ⟨"Large", ptm 14400, ptm 18000⟩, ⟨"LARGE", ptm 17280, ptm 22000⟩,
    ⟨"huge", ptm 20740, ptm 25000⟩, ⟨"Huge", ptm 24880, ptm 30000⟩]

/-- The eleven-point sizes. -/
def sizes11 : Array SizeSpec :=
  #[⟨"tiny", ptm 6000, ptm 7000⟩, ⟨"scriptsize", ptm 8000, ptm 9500⟩,
    ⟨"footnotesize", ptm 9000, ptm 11000⟩, ⟨"small", ptm 10000, ptm 12000⟩,
    ⟨"normalsize", ptm 10950, ptm 13600⟩, ⟨"large", ptm 12000, ptm 14000⟩,
    ⟨"Large", ptm 14400, ptm 18000⟩, ⟨"LARGE", ptm 17280, ptm 22000⟩,
    ⟨"huge", ptm 20740, ptm 25000⟩, ⟨"Huge", ptm 24880, ptm 30000⟩]

/-- The twelve-point sizes. -/
def sizes12 : Array SizeSpec :=
  #[⟨"tiny", ptm 6000, ptm 7000⟩, ⟨"scriptsize", ptm 8000, ptm 9500⟩,
    ⟨"footnotesize", ptm 10000, ptm 12000⟩, ⟨"small", ptm 10950, ptm 13600⟩,
    ⟨"normalsize", ptm 12000, ptm 14500⟩, ⟨"large", ptm 14400, ptm 18000⟩,
    ⟨"Large", ptm 17280, ptm 22000⟩, ⟨"LARGE", ptm 20740, ptm 25000⟩,
    ⟨"huge", ptm 24880, ptm 30000⟩, ⟨"Huge", ptm 24880, ptm 30000⟩]

/-- Glue of a width, stretch and shrink in sp. -/
def gsp (w st sh : Int) : Glue := { width := w, stretch := st, shrink := sh }

/-- The entry of `ClassParams.sizeSkips` for a size command: `\topsep`, `\itemsep` (also
`\parsep`) and the three display skips, in sp (width, stretch, shrink each). -/
def sizeSkip (name : String) (top item disp short bshort : Int × Int × Int) :
    String × (Glue × Glue × Glue) × (Glue × Glue × Glue) :=
  let g := fun (x : Int × Int × Int) => gsp x.1 x.2.1 x.2.2
  (name, (g top, g item, g item), (g disp, g short, g bshort))

/-- A list level from its skips (thousandths of a point: width, stretch, shrink) and its left
margin (sp). -/
def listLevel (top partop item par : Int × Int × Int) (left : Int) : ListLevel :=
  { topSep := glueM top.1 top.2.1 top.2.2, parTopSep := glueM partop.1 partop.2.1 partop.2.2,
    itemSep := glueM item.1 item.2.1 item.2.2, parSep := glueM par.1 par.2.1 par.2.2,
    leftMargin := left }

/-- The class's parameters for a base size (10, 11 or 12; others as 10) and paper. -/
def classParams (o : ClassOptions) : ClassParams :=
  let (pw, ph) := if o.a4 then (39158276, 55380990) else (40258437, 52099153)
  match o.size with
  | 11 =>
    { paperWidth := pw, paperHeight := ph, textWidth := 23592960,
      textHeight := if o.a4 then 39046366 else 35481206,
      oddSideMargin := if o.a4 then 3014656 else 3538944,
      topMargin := if o.a4 then 1179648 else 1376256,
      headHeight := ptm 12000, headSep := ptm 25000, footSkip := ptm 30000,
      topSkip := ptm 11000, maxDepth := ptm 5500, parIndent := ptm 17000, sizes := sizes11,
      displaySkip := glueM 11000 3000 6000, belowShortSkip := glueM 6500 3500 3000,
      footnoteSep := 504627, footinsSkip := glueM 10000 4000 2000,
      floatSep := glueM 12000 2000 2000, textFloatSep := glueM 20000 2000 4000,
      inTextSep := glueM 12000 2000 2000, fpSep := ⟨ptm 8000, 2 * 65536, 1, 0, 0⟩,
      lists := #[listLevel (9000, 3000, 5000) (3000, 1000, 1000) (4500, 2000, 1000)
          (4500, 2000, 1000) 1794047,
        listLevel (4500, 2000, 1000) (3000, 1000, 1000) (2000, 1000, 1000) (2000, 1000, 1000)
          1578759,
        listLevel (2000, 1000, 1000) (1000, 0, 1000) (2000, 1000, 1000) (0, 0, 0) 1341944,
        listLevel (2000, 1000, 1000) (1000, 0, 1000) (2000, 1000, 1000) (0, 0, 0) 1219950],
      leftMarginDeep := 717619, labelSep := 358809, marginparWidth := ptm 59000,
      sizeSkips := #[
        sizeSkip "small" (393216, 131072, 131072) (196608, 131072, 65536)
          (655360, 131072, 327680) (0, 196608, 0) (393216, 196608, 196608),
        sizeSkip "footnotesize" (262144, 131072, 131072) (131072, 65536, 65536)
          (524288, 131072, 262144) (0, 65536, 0) (262144, 131072, 131072)] }
  | 12 =>
    { paperWidth := pw, paperHeight := ph, textWidth := 25559040,
      textHeight := if o.a4 then 38797312 else 35946496,
      oddSideMargin := if o.a4 then 2031616 else 2555904,
      topMargin := if o.a4 then 1310720 else 1114112,
      headHeight := ptm 12000, headSep := ptm 25000, footSkip := ptm 30000,
      topSkip := ptm 12000, maxDepth := ptm 6000, parIndent := ptm 18000, sizes := sizes12,
      displaySkip := glueM 12000 3000 7000, belowShortSkip := glueM 6500 3500 3000,
      footnoteSep := 550502, footinsSkip := glueM 10800 4000 2000,
      floatSep := glueM 12000 2000 4000, textFloatSep := glueM 20000 2000 4000,
      inTextSep := glueM 14000 4000 4000, fpSep := ⟨ptm 10000, 2 * 65536, 1, 0, 0⟩,
      lists := #[listLevel (10000, 4000, 6000) (3000, 2000, 2000) (5000, 2500, 1000)
          (5000, 2500, 1000) 1966080,
        listLevel (5000, 2500, 1000) (3000, 2000, 2000) (2500, 1000, 1000) (2500, 1000, 1000)
          1730148,
        listLevel (2500, 1000, 1000) (1000, 0, 1000) (2500, 1000, 1000) (0, 0, 0) 1470624,
        listLevel (2500, 1000, 1000) (1000, 0, 1000) (2500, 1000, 1000) (0, 0, 0) 1336932],
      leftMarginDeep := 786432, labelSep := 393216, marginparWidth := ptm 44000,
      sizeSkips := #[
        sizeSkip "small" (589824, 196608, 327680) (294912, 131072, 65536)
          (720896, 196608, 393216) (0, 196608, 0) (425984, 229376, 196608),
        sizeSkip "footnotesize" (393216, 131072, 131072) (196608, 131072, 65536)
          (655360, 131072, 327680) (0, 196608, 0) (393216, 196608, 196608)] }
  | _ =>
    { paperWidth := pw, paperHeight := ph, textWidth := 22609920,
      textHeight := if o.a4 then 39190528 else 36044800,
      oddSideMargin := if o.a4 then 3473408 else 4063232,
      topMargin := if o.a4 then 1114112 else 1048576,
      headHeight := ptm 12000, headSep := ptm 25000, footSkip := ptm 30000,
      topSkip := ptm 10000, maxDepth := ptm 5000, parIndent := ptm 15000, sizes := sizes10,
      displaySkip := glueM 10000 2000 5000, belowShortSkip := glueM 6000 3000 3000,
      footnoteSep := 435814, footinsSkip := glueM 9000 4000 2000,
      floatSep := glueM 12000 2000 2000, textFloatSep := glueM 20000 2000 4000,
      inTextSep := glueM 12000 2000 2000, fpSep := ⟨ptm 8000, 2 * 65536, 1, 0, 0⟩,
      lists := #[listLevel (8000, 2000, 4000) (2000, 1000, 1000) (4000, 2000, 1000)
          (4000, 2000, 1000) 1638400,
        listLevel (4000, 2000, 1000) (2000, 1000, 1000) (2000, 1000, 1000) (2000, 1000, 1000)
          1441790,
        listLevel (2000, 1000, 1000) (1000, 0, 1000) (2000, 1000, 1000) (0, 0, 0) 1225520,
        listLevel (2000, 1000, 1000) (1000, 0, 1000) (2000, 1000, 1000) (0, 0, 0) 1114110],
      leftMarginDeep := 655360, labelSep := 327680, marginparWidth := ptm 65000,
      sizeSkips := #[
        sizeSkip "small" (262144, 131072, 131072) (131072, 65536, 65536)
          (557056, 196608, 262144) (0, 131072, 0) (262144, 131072, 131072),
        sizeSkip "footnotesize" (196608, 65536, 65536) (131072, 65536, 65536)
          (393216, 131072, 262144) (0, 65536, 0) (196608, 65536, 131072)] }

/-- A heading command's parameters (LaTeX's `\@startsection`): its level, its indentation,
the skip before it (negative: the first paragraph after it is not indented), the skip after
it (negative: a run-in heading, set at the start of the next paragraph), and its size command
(the font is bold). Skips are in thousandths of an ex of the current font (`ex`) or of a
point (`pt`) and of an em (`em`). -/
structure SectionSpec where
  /-- The level: 1 `section` … 5 `subparagraph`. -/
  level : Nat
  /-- Indentation from the parameter `\parindent` (`subparagraph`) or none. -/
  indentParindent : Bool := false
  /-- The skip before, in thousandths of an ex: natural, stretch, shrink. -/
  skipBefore : Int × Int × Int
  /-- The skip after, in thousandths of an ex (positive) or of an em (negative, run-in). -/
  skipAfter : Int × Int × Int
  /-- The size command of the heading's font. -/
  size : String
  deriving Inhabited, Repr

/-- The article class's headings. -/
def sectionSpec? : String → Option SectionSpec
  | "section" => some ⟨1, false, (3500, 1000, 200), (2300, 200, 0), "Large"⟩
  | "subsection" => some ⟨2, false, (3250, 1000, 200), (1500, 200, 0), "large"⟩
  | "subsubsection" => some ⟨3, false, (3250, 1000, 200), (1500, 200, 0), "normalsize"⟩
  | "paragraph" => some ⟨4, false, (3250, 1000, 200), (-1000, 0, 0), "normalsize"⟩
  | "subparagraph" => some ⟨5, true, (3250, 1000, 200), (-1000, 0, 0), "normalsize"⟩
  | _ => none

end LeAnTeX.Doc
