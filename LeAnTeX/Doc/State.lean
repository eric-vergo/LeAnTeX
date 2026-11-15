/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.VList
import LeAnTeX.Text.Source

/-!
# The document layer's state

What the LaTeX front end keeps about a document besides the paragraph being built: counters,
labels and the references of the previous pass, the table of contents, the environments open,
the lists and their parameters, theorem and environment definitions, floats and footnotes, the
class's options and the title. Every field has a plain value, so a pass of the front end is a
pure function of the source and of the previous pass's labels and contents.

## Main definitions

* `Counter`: a LaTeX counter (its value and the counters reset when it is stepped).
* `FrameKind`: what a nested vertical list is being built for (a footnote, a float, a box).
* `ListLevel`: the parameters of a list environment (LaTeX's `\list`).
* `FloatItem`: a figure or table: its box, placement and caption number.
* `TocEntry`: a line of the table of contents.
* `DocState`: all of it.
-/

namespace LeAnTeX.Doc

open LeAnTeX.Text

/-- A LaTeX counter: its value and the counters reset to zero when it is stepped (`\newcounter
{x}[y]` adds `x` to `y`'s list). -/
structure Counter where
  /-- The value. -/
  value : Int := 0
  /-- The counters reset when this one is stepped. -/
  resets : Array String := #[]
  deriving Inhabited, Repr

/-- The table of counters, by name. -/
structure Counters where
  /-- The counters. -/
  table : Std.HashMap String Counter := {}
  deriving Inhabited

/-- What a nested vertical list (TeX's internal vertical mode) is built for. -/
inductive FrameKind where
  /-- A footnote's text: an insertion at the place of the mark. -/
  | footnote
  /-- A float's body: the float of that index. -/
  | float (index : Nat)
  /-- A `\parbox` or `minipage` of a width, or a `p{…}` table cell: a box placed in the
  horizontal list; `pos` is `t`, `c` or `b` (top line, centre, bottom line on the
  baseline). -/
  | parbox (width : Int) (pos : Char)
  /-- The title block of `\maketitle`. -/
  | title
  deriving Inhabited, BEq, Repr

/-- The parameters of a list environment at one level (LaTeX's `\list`, its `\@listi` …
`\@listvi` and the environment's own settings). -/
structure ListLevel where
  /-- `\topsep`. -/
  topSep : Glue := {}
  /-- `\partopsep`. -/
  parTopSep : Glue := {}
  /-- `\itemsep`. -/
  itemSep : Glue := {}
  /-- `\parsep`. -/
  parSep : Glue := {}
  /-- `\leftmargin`. -/
  leftMargin : Int := 0
  /-- `\rightmargin`. -/
  rightMargin : Int := 0
  /-- `\labelwidth`. -/
  labelWidth : Int := 0
  /-- `\labelsep`. -/
  labelSep : Int := 0
  /-- `\itemindent`. -/
  itemIndent : Int := 0
  /-- `\listparindent`. -/
  listParIndent : Int := 0
  /-- The label of an `\item` without its own: tokens. -/
  label : Array Tok := #[]
  /-- The counter `\item` steps, if any. -/
  counter : Option String := none
  /-- How a label is set: 0 flush right in `\labelwidth` (`\hfil` before it), 1 as
  `description` sets it (bold, at its natural width). -/
  labelStyle : Nat := 0
  /-- Whether the list is a trivial list (`center`, `quote`'s skips only, no items). -/
  trivial : Bool := false
  /-- LaTeX's `\@topsepadd`: `\topsep`, with `\partopsep` when the list began in vertical
  mode. -/
  topSepAdd : Glue := {}
  /-- LaTeX's `\@topsep`: `\@topsepadd` plus the `\parskip` outside. -/
  topSepItem : Glue := {}
  /-- The `\parskip` outside the list. -/
  outerParSkip : Glue := {}
  /-- Whether no item has come yet. -/
  newList : Bool := true
  /-- Whether the list began right after an item's label (no skips of its own). -/
  noParList : Bool := false
  /-- Whether the label is set at its natural width (`description`). -/
  naturalLabel : Bool := false
  deriving Inhabited

/-- A figure or table: its kind (`figure`, `table`), the placement it allows (`htbp`
letters, `!` ignored), its body as a vertical box, its number (when captioned) and where it
was given in the source. -/
structure FloatItem where
  /-- `figure` or `table`. -/
  kind : String
  /-- The placement letters. -/
  placement : String := "tbp"
  /-- Its body. -/
  box : VBox := { width := 0, height := 0, depth := 0, content := #[], glue := {} }
  /-- Its number as printed, if it has a caption. -/
  number : Option String := none
  deriving Inhabited

/-- A line of the table of contents: the level (1 section … 5 subparagraph), the number as
printed (empty for an unnumbered heading given with `\addcontentsline`), the title's source
tokens and the label key of its page anchor. -/
structure TocEntry where
  /-- The level. -/
  level : Nat
  /-- The number. -/
  number : String
  /-- The title. -/
  title : Array Tok
  /-- The page anchor's key. -/
  anchor : String
  deriving Inhabited

/-- A user-defined environment (`\newenvironment`): its parameters, the default of an
optional first one, and the code at its beginning and end. -/
structure EnvDef where
  /-- The number of parameters. -/
  params : Nat := 0
  /-- The default of the optional first parameter. -/
  default : Option (Array Tok) := none
  /-- The code at `\begin`. -/
  begin_ : Array Tok := #[]
  /-- The code at `\end`. -/
  end_ : Array Tok := #[]
  deriving Inhabited

/-- A theorem-like environment (`\newtheorem`): its printed name, its counter, and the style
(`plain`, `definition`, `remark` with `amsthm`; the kernel's own when `amsthm` is not
loaded). -/
structure TheoremDef where
  /-- The name printed in the head. -/
  name : Array Tok
  /-- The counter, `none` for the starred (unnumbered) form. -/
  counter : Option String
  /-- The style. -/
  style : String := "plain"
  deriving Inhabited

/-- An open environment: its name, and the code to run at its end. -/
structure EnvFrame where
  /-- The name. -/
  name : String
  /-- The tokens `\end` carries out before closing the group. -/
  end_ : Array Tok := #[]
  /-- The group depth when it began. -/
  depth : Nat := 0
  deriving Inhabited

/-- A column of a table's preamble: its alignment (`l`, `c`, `r`, `p`), the width of a `p`
column, the rules before and after it, and whether `\tabcolsep` is left out on either side
(`@{}`). -/
structure Column where
  /-- `l`, `c`, `r` or `p`. -/
  align : Char := 'l'
  /-- The width of a `p` column. -/
  width : Int := 0
  /-- Rules before the column (the first column only; others carry them after the previous
  column). -/
  rulesBefore : Nat := 0
  /-- Rules after it. -/
  rulesAfter : Nat := 0
  /-- No `\tabcolsep` on the left. -/
  noSepLeft : Bool := false
  /-- No `\tabcolsep` on the right. -/
  noSepRight : Bool := false
  deriving Inhabited, Repr

/-- A table cell as set: its material (the cell's horizontal list; a `p` cell's is one box),
its natural size, the columns it spans and its own preamble (`\multicolumn`). -/
structure Cell where
  /-- The material. -/
  content : Array HNode := #[]
  /-- The natural width. -/
  width : Int := 0
  /-- The height. -/
  height : Int := 0
  /-- The depth. -/
  depth : Int := 0
  /-- The columns spanned. -/
  span : Nat := 1
  /-- Its own column, for a `\multicolumn`. -/
  own : Option Column := none
  deriving Inhabited

/-- A row of a table: its cells and extra depth (`\\[dim]`), or rules (`\hline`, one per
rule, `\doublerulesep` between). -/
inductive Row where
  /-- A row of cells. -/
  | cells (cs : Array Cell) (extra : Int)
  /-- `\hline` repeated `n` times. -/
  | hline (n : Nat)
  deriving Inhabited

/-- A table being built: its position (`t`, `c`, `b`), its columns, the rows so far, the
current row's cells, the current cell's column, span and own preamble, the group depth of the
current cell, and whether the current cell is a `p` cell (a nested vertical list) and has had
any material. -/
structure Table where
  /-- `t`, `c` or `b`. -/
  pos : Char := 'c'
  /-- The columns. -/
  cols : Array Column := #[]
  /-- The rows done. -/
  rows : Array Row := #[]
  /-- The current row's cells. -/
  cells : Array Cell := #[]
  /-- The current cell's first column. -/
  col : Nat := 0
  /-- The current cell's span. -/
  span : Nat := 1
  /-- The current cell's own preamble. -/
  own : Option Column := none
  /-- The group depth of the current cell. -/
  depth : Nat := 0
  /-- Whether the current cell is a `p` cell. -/
  pcell : Bool := false
  /-- Whether the current cell has material (anything typed in it). -/
  touched : Bool := false
  /-- The array's environment (`tabular`) or `array`. -/
  env : String := "tabular"
  deriving Inhabited

/-- The class's options and the title block. -/
structure ClassOptions where
  /-- The base size in points: 10, 11 or 12. -/
  size : Nat := 10
  /-- Whether the paper is A4 (else US letter). -/
  a4 : Bool := false
  deriving Inhabited, Repr

/-- The document layer's state (see the module docstring). -/
structure DocState where
  /-- Whether the source has a `\documentclass` (document mode). -/
  documentMode : Bool := false
  /-- Whether `\begin{document}` has been read. -/
  inDocument : Bool := false
  /-- Whether `\end{document}` has been read. -/
  ended : Bool := false
  /-- The class options. -/
  options : ClassOptions := {}
  /-- The packages loaded. -/
  packages : Array String := #[]
  /-- The counters. -/
  counters : Counters := {}
  /-- How each counter is printed (`\the<name>`'s body), by name. -/
  counterFormats : Std.HashMap String (Array Tok) := {}
  /-- `\@currentlabel`: what a `\label` records. -/
  currentLabel : String := ""
  /-- The labels defined in this pass: key, text, page anchor. -/
  labels : Array (String × String) := #[]
  /-- The references of the previous pass: key to text and page. -/
  refs : Std.HashMap String (String × String) := {}
  /-- References to keys no label defines (reported). -/
  undefinedRefs : Array String := #[]
  /-- The table of contents of this pass. -/
  toc : Array TocEntry := #[]
  /-- The table of contents of the previous pass, with each entry's page. -/
  prevToc : Array (TocEntry × String) := #[]
  /-- The open environments, innermost last. -/
  envs : Array EnvFrame := #[]
  /-- The lists open, innermost last. -/
  lists : Array ListLevel := #[]
  /-- Whether the next `\item`'s label waits to start its paragraph. -/
  inLabel : Bool := false
  /-- The label box of the next item. -/
  labelBox : Option HNode := none
  /-- Whether the first paragraph after a heading or list start is coming (LaTeX's
  `\@nobreak`: no break above it; `\clubpenalty` 10000 for its first line). -/
  noBreak : Bool := false
  /-- Whether the next paragraph is to start without its indentation after a heading. -/
  afterHeading : Bool := false
  /-- Whether the next paragraph, if it follows at once, continues after an environment
  without indentation (LaTeX's `\@endpe`). -/
  endPe : Bool := false
  /-- The user environments. -/
  environments : Std.HashMap String EnvDef := {}
  /-- The theorem environments. -/
  theorems : Std.HashMap String TheoremDef := {}
  /-- The images read so far, by path: the id, the `data:` URL, and the natural width and
  height in sp. Each file is read and encoded once, however often it is included. -/
  images : Std.HashMap String (String × String × Int × Int) := {}
  /-- The bytes of the distinct images read so far (against `Settings.maxImagesTotal`). -/
  imageBytes : Nat := 0
  /-- The current theorem style (`\theoremstyle`). -/
  theoremStyle : String := "plain"
  /-- The floats, by index. -/
  floats : Array FloatItem := #[]
  /-- The footnote marks of footnotes being built (the innermost last). -/
  footnoteMarks : Array String := #[]
  /-- `\title`, `\author`, `\date`. -/
  title : Array Tok := #[]
  /-- `\author`. -/
  author : Array Tok := #[]
  /-- `\date`; `none` for `\today`. -/
  date : Option (Array Tok) := none
  /-- `\thanks` notes of the title block. -/
  thanks : Array (Array Tok) := #[]
  /-- The page style: `plain` or `empty`; with the style of the current page if set. -/
  pageStyle : String := "plain"
  /-- `\thispagestyle`: the page anchor key and its style. -/
  thisPageStyles : Array (String × String) := #[]
  /-- A counter of anchors made (each `\label`, heading and `\thispagestyle` gets one). -/
  anchors : Nat := 0
  /-- User lengths (`\newlength`) and LaTeX's layout lengths, as glue. -/
  lengths : Std.HashMap String Glue := {}
  /-- Whether the title block is being set (`\thanks` marks are symbols there). -/
  inTitle : Bool := false
  /-- The tables being built, innermost last. -/
  tables : Array Table := #[]
  /-- The counter steps, in order: the counter and its printed value after the step. -/
  steps : Array (String × String) := #[]
  /-- Warnings of the document layer (undefined references, unknown packages). -/
  warnings : Array String := #[]
  deriving Inhabited

end LeAnTeX.Doc
