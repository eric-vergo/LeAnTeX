/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import VersoManual
import LeAnTeX
-- a hash of the repository files the pages read: a changed file rebuilds the pages
import LeAnTeXManualInputs

/-!
# The manual's elements

The pages are written in Verso's `Manual` genre. This module adds the elements that tie them to
the repository, so that a page cannot say something the code or the committed records do not:

* `{svgOf f}`, `{pagesOf f}` and `{htmlOf f}` run a function `f` that a `lean` block of the same
  page defines, with the fonts of `fonts/newcomputermodern`, while the page is elaborated, and
  embed what it returns: the SVG picture (or pictures, one per page of a document) as an image,
  the HTML page in a frame without scripts. A sample LeAnTeX refuses fails the build with its
  error. `{htmlSourceOf f}` shows the first lines of the HTML text itself, and `{linesOf f}`
  the lines a function returns (a document's warnings).
* `{file}` with a path in backticks: a file of the repository, which must exist, linked to the
  repository's copy.
* `{api}` with a module name in backticks: the module's page in the API reference.
* `{quoteSection "FILE" "HEADING"}`: the section of a Markdown file of the repository under that
  heading, rendered as it stands when the manual is built (its tables included).
* `{fileText "FILE"}`: a text file of the repository in full, as preformatted text.

Every element is checked when the page is elaborated: a missing file, heading, module or a
sample that does not typeset is an error, so a renamed file or a changed notice breaks the
manual's build instead of leaving a stale page.

## Samples

LeAnTeX is loaded into the elaborator as its compiled shared library (see the lakefile), so a
sample costs what it costs a program: reading the fonts (once per page, about a second and a
half) and typesetting. The pictures are embedded as `data:` URLs in `<img>` elements: an image
document runs no script, and the pictures' glyph definitions cannot clash between pictures on
one page. Each picture and page is also checked for script, event handlers, embedded documents
and external references before it is embedded (`inertProblem?`).
-/

open Verso Genre Manual Doc Elab ArgParse
open Lean Elab
open Verso.Output (Html)

namespace LeAnTeXManual

/-- The public repository the manual documents: its files are linked from the pages. -/
def repositoryUrl : String := "https://github.com/eric-vergo/LeAnTeX"

/-- The repository's root: the folder above the manual's (Lake elaborates the pages and runs the
site generator in `manual/`). -/
def repoRoot : IO System.FilePath := do
  for c in [("..": System.FilePath), "."] do
    if (← (c / "LeAnTeX.lean").pathExists) && (← (c / "manual" / "lakefile.lean").pathExists) then
      return c
  throw <| IO.userError
    "the repository's root (with LeAnTeX.lean and manual/) is neither here nor one folder up"

/-- Whether `p` names a file inside the repository: relative, no `..` segment, no empty or
`.` segment. -/
def safeRepoPath (p : String) : Bool :=
  !p.isEmpty && !p.startsWith "/" &&
    (p.splitOn "/").all fun s => !s.isEmpty && s != ".." && s != "."

/-- The text of a file of the repository (`path` relative to the root). -/
def readRepoFile (path : String) : IO String := do
  unless safeRepoPath path do
    throw <| IO.userError s!"{path}: not a path inside the repository"
  let f := (← repoRoot) / path
  unless ← f.pathExists do throw <| IO.userError s!"{path}: no such file in the repository"
  IO.FS.readFile f

/-! ## Fonts and samples -/

/-- The fonts the samples are typeset with, read once per elaboration. -/
initialize fontCache : IO.Ref (Option LeAnTeX.Backend.Fonts) ← IO.mkRef none

/-- The New Computer Modern fonts of the repository (`fonts/newcomputermodern`), read on first
use. A missing or unreadable file is an error: a sample must not be typeset with fewer fonts
than a reader's program would have. -/
def sampleFonts : IO LeAnTeX.Backend.Fonts := do
  if let some f ← fontCache.get then return f
  let dir := (← repoRoot) / "fonts" / "newcomputermodern"
  let (fonts, missing) ← LeAnTeX.Backend.Fonts.load dir
  unless missing.isEmpty do
    throw <| IO.userError s!"fonts missing or unreadable in {dir}: {missing}"
  fontCache.set (some fonts)
  return fonts

/-- The standard Base64 encoding of `b` (RFC 4648, with padding). -/
def base64 (b : ByteArray) : String := Id.run do
  let tbl := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toList.toArray
  let mut out := ""
  for i in [0:b.size:3] do
    let b0 := b[i]!.toNat
    let b1 := if i + 1 < b.size then b[i + 1]!.toNat else 0
    let b2 := if i + 2 < b.size then b[i + 2]!.toNat else 0
    let n := b0 * 65536 + b1 * 256 + b2
    out := out.push tbl[n / 262144 % 64]!
    out := out.push tbl[n / 4096 % 64]!
    out := out.push (if i + 1 < b.size then tbl[n / 64 % 64]! else '=')
    out := out.push (if i + 2 < b.size then tbl[n % 64]! else '=')
  return out

/-- Whether `s` has, at character index `i`, an attribute name starting with `on` after white
space and followed by `=`: an event handler. -/
def eventHandlerAt (cs : Array Char) (i : Nat) : Bool := Id.run do
  unless (cs[i]?.getD 'x').isWhitespace && cs[i + 1]? == some 'o' && cs[i + 2]? == some 'n' do
    return false
  let mut j := i + 3
  let mut letters := 0
  while j < cs.size && (cs[j]!.isAlpha) do
    j := j + 1
    letters := letters + 1
  return letters > 0 && cs[j]? == some '='

/-- Why the markup `s` (a picture or a page a sample made) is not inert, if it is not: a script,
an event handler, an embedded document or object, a `javascript:` address, or an address that
leaves the page (`http:`, `https:`, `//`). -/
def inertProblem? (s : String) : Option String := Id.run do
  let low := s.toLower
  for bad in ["<script", "<foreignobject", "<iframe", "<object", "<embed", "javascript:",
      "http:", "https:", "url(//", "href=\"//"] do
    -- the SVG and XLink namespace names are identifiers, not addresses
    let t := (low.replace "xmlns=\"http://www.w3.org/2000/svg\"" "").replace
      "xmlns:xlink=\"http://www.w3.org/1999/xlink\"" ""
    if (t.splitOn bad).length > 1 then return some s!"it contains `{bad}`"
  let cs := low.toList.toArray
  for i in [0:cs.size] do
    if eventHandlerAt cs i then return some "it contains an event handler attribute"
  return none

/-- The text of the first `<title>` element of an SVG picture, decoded: the source the picture
was typeset from, which the back end writes there. -/
def svgTitle? (svg : String) : Option String := do
  let after ← (svg.splitOn "<title>")[1]?
  let body ← (after.splitOn "</title>")[0]?
  return String.ofList (LeAnTeX.Backend.unescapeList body.toList)

/-- The width of an SVG picture in points, from its root element's `width="…pt"`, rounded to a
whole point. -/
def svgWidthPt? (svg : String) : Option Nat := do
  let afterSvg ← (svg.splitOn "<svg")[1]?
  let after ← (afterSvg.splitOn " width=\"")[1]?
  let num ← (after.splitOn "pt\"")[0]?
  let whole := (num.splitOn ".").headD num
  whole.toNat?

/-- CSS pixels per point at which a kind of sample is shown: formulas and paragraphs larger than
print size (a point is 4/3 of a CSS pixel at print size), pages at about half. -/
def pictureScale (kind : String) : Nat :=
  if kind == "pages" then 1 else 2

block_extension Block.pictures (svgs : Array String) (alts : Array String) (kind : String) where
  data := Json.arr #[Json.arr (svgs.map Json.str), Json.arr (alts.map Json.str), Json.str kind]
  traverse _ _ _ := pure none
  toTeX := some fun _ go _ _ content => content.mapM go
  toHtml := open Verso.Output.Html in some fun _ go _ data content => do
    match data with
    | .arr #[.arr svgs, .arr alts, .str kind] =>
      let imgs : Array Html := (svgs.zip alts).map fun
        | (.str svg, .str alt) =>
          let src := "data:image/svg+xml;base64," ++ base64 svg.toUTF8
          let w := match svgWidthPt? svg with
            | some pt => s!"width: {pt * pictureScale kind}px"
            | none => ""
          html%{<img class="ltx-picture" src={src} alt={alt} style={w}/>}
        | _ => .empty
      let caption ← content.mapM go
      pure html%{<figure class={"ltx-sample ltx-" ++ kind}><div class="ltx-paper">{imgs}</div>
        <figcaption>{caption}</figcaption></figure>}
    | _ => pure .empty

block_extension Block.htmlFrame (page : String) (height : Nat) where
  data := Json.arr #[Json.str page, Lean.toJson height]
  traverse _ _ _ := pure none
  toTeX := some fun _ go _ _ content => content.mapM go
  toHtml := open Verso.Output.Html in some fun _ go _ data content => do
    match data with
    | .arr #[.str page, h] =>
      let height : Nat := (Lean.fromJson? h).toOption.getD 200
      let caption ← content.mapM go
      pure html%{<figure class="ltx-sample ltx-html"><iframe class="ltx-frame" srcdoc={page}
        sandbox="allow-same-origin" referrerpolicy="no-referrer" loading="lazy"
        style={s!"height: {height}px"} title="An HTML page written by LeAnTeX"></iframe>
        <figcaption>{caption}</figcaption></figure>}
    | _ => pure .empty

/-- The arguments of the sample elements: the function that makes the sample, and (for HTML)
the height of the frame in CSS pixels. -/
structure SampleArgs where
  /-- The function, defined in a `lean` block of the page. -/
  fn : Ident
  /-- The frame's height, for `htmlOf`. -/
  height : Nat
  /-- How many lines `htmlSourceOf` shows. -/
  lines : Nat

instance : FromArgs SampleArgs DocElabM where
  fromArgs := SampleArgs.mk <$> .positional `fn .ident <*> .namedD `height .nat 240 <*>
    .namedD `lines .nat 14

/-- Evaluates `f`, which must have type `type`, in the page's environment. -/
unsafe def evalFnUnsafe (α : Type) [Inhabited α] (type : Term) (f : Ident) : TermElabM α := do
  let ty ← Term.elabType type
  Term.evalTerm α ty f

/-- A function that typesets one source, as `LeAnTeX.Backend.render` does. -/
abbrev RenderFn := LeAnTeX.Backend.Fonts → Except (Nat × String) String

/-- A function that typesets a document into one picture per page. -/
abbrev PagesFn := LeAnTeX.Backend.Fonts → Except String (Array String)

@[implemented_by evalFnUnsafe]
opaque evalFn (α : Type) [Inhabited α] (type : Term) (f : Ident) : TermElabM α

/-- Runs a render function of the page on the sample fonts, failing the build with LeAnTeX's
error. -/
def runRender (f : Ident) : DocElabM String := do
  let fn ← evalFn RenderFn (← `(LeAnTeXManual.RenderFn)) f
  let fonts ← sampleFonts
  match fn fonts with
  | .ok s => return s
  | .error (pos, msg) => throwErrorAt f "LeAnTeX did not typeset the sample: at {pos}: {msg}"

/-- Fails unless `s` is inert (`inertProblem?`). -/
def checkInert (f : Ident) (what s : String) : DocElabM Unit := do
  if let some why := inertProblem? s then
    throwErrorAt f "the {what} {f.getId} made is not embedded: {why}"

/-- `{svgOf f}`: the SVG picture `f : Fonts → Except (Nat × String) String` returns, as an image
whose alternative text is the picture's own title (the source). The blocks after it, up to the
end of the directive, are its caption: written `:::svgOf f` … `:::`. -/
@[directive]
def svgOf : DirectiveExpanderOf SampleArgs
  | {fn, ..}, blocks => do
    let svg ← runRender fn
    checkInert fn "picture" svg
    let alt := (svgTitle? svg).getD "A picture typeset by LeAnTeX"
    ``(Block.other (Block.pictures #[$(quote svg)] #[$(quote alt)] "svg")
        #[$[$(← blocks.mapM elabBlock)],*])

/-- `:::pagesOf f` … `:::`: the pages `f : Fonts → Except String (Array String)` returns (one
SVG picture each), side by side, with the blocks inside as the caption. -/
@[directive]
def pagesOf : DirectiveExpanderOf SampleArgs
  | {fn, ..}, blocks => do
    let g ← evalFn PagesFn (← `(LeAnTeXManual.PagesFn)) fn
    let pages ← match g (← sampleFonts) with
      | .ok ps => pure ps
      | .error msg => throwErrorAt fn "LeAnTeX did not typeset the document: {msg}"
    if pages.isEmpty then throwErrorAt fn "the document has no pages"
    for p in pages do checkInert fn "page" p
    let alts := (Array.range pages.size).map fun i => s!"Page {i + 1} of the sample document"
    ``(Block.other (Block.pictures $(quote pages) $(quote alts) "pages")
        #[$[$(← blocks.mapM elabBlock)],*])

/-- The font files the site carries for the HTML samples (`Main.lean` copies them into the
site's `fonts/` folder). An HTML sample that asks for another font fails the build. -/
def siteFonts : List String := ["NewCM10-Book.otf", "NewCM10-BookItalic.otf", "NewCM10-Bold.otf"]

/-- Where the HTML samples find the fonts, relative to the page that embeds them (the pages of
the guide's chapters are one level below the site's root). -/
def siteFontUrl : String := "../fonts"

/-- The font files an HTML page asks for in its `@font-face` rules (the last segment of each
`url("…")`). -/
def fontUrls (page : String) : List String :=
  ((page.splitOn "url(\"").drop 1).map fun s =>
    let u := (s.splitOn "\"").headD ""
    ((u.splitOn "/").getLast?).getD u

/-- `:::htmlOf f (height := 240)` … `:::`: the HTML page `f` returns, shown in a frame that runs
no script (`sandbox` without `allow-scripts`). `f` must write its fonts' address as
`siteFontUrl`, and ask only for `siteFonts`. -/
@[directive]
def htmlOf : DirectiveExpanderOf SampleArgs
  | {fn, height, ..}, blocks => do
    let page ← runRender fn
    let low := page.toLower
    if (low.splitOn "<script").length > 1 then
      throwErrorAt fn "the page {fn.getId} made contains a script"
    for u in fontUrls page do
      unless siteFonts.contains u do
        throwErrorAt fn "the page asks for the font {u}, which the site does not carry \
          (LeAnTeXManual.siteFonts)"
    unless (page.splitOn s!"url(\"{siteFontUrl}/").length > 1 || (fontUrls page).isEmpty do
      throwErrorAt fn "the page does not load its fonts from {siteFontUrl}"
    ``(Block.other (Block.htmlFrame $(quote page) $(quote height))
        #[$[$(← blocks.mapM elabBlock)],*])

/-- `{htmlSourceOf f (lines := 14)}`: the first lines of the HTML text `f` returns, as code. -/
@[block_command]
def htmlSourceOf : BlockCommandOf SampleArgs
  | {fn, lines, ..} => do
    let page ← runRender fn
    let shown := (page.splitOn "\n").take lines
    let more := (page.splitOn "\n").length - shown.length
    let text := "\n".intercalate shown ++ (if more > 0 then s!"\n… ({more} more lines)" else "")
    ``(Block.code $(quote text))

/-- `{linesOf f}`: the lines `f : Fonts → Except String (Array String)` returns (a document's
warnings, say), as code; `(none)` when there are none. -/
@[block_command]
def linesOf : BlockCommandOf SampleArgs
  | {fn, ..} => do
    let g ← evalFn PagesFn (← `(LeAnTeXManual.PagesFn)) fn
    match g (← sampleFonts) with
    | .ok ls =>
      let text := if ls.isEmpty then "(none)" else "\n".intercalate ls.toList
      ``(Block.code $(quote text))
    | .error e => throwErrorAt fn "LeAnTeX did not typeset the sample: {e}"

/-! ## Files of the repository -/

inline_extension Inline.repoFile (path : String) where
  data := Json.str path
  traverse _ _ _ := pure none
  toTeX := some fun go _ _ content => content.mapM go
  toHtml := open Verso.Output.Html in some fun _ _ data _ => do
    match data with
    | .str p =>
      let href := s!"{repositoryUrl}/blob/main/{p}"
      pure html%{<a class="ltx-file" href={href}><code>{Html.text p}</code></a>}
    | _ => pure .empty

/-- The text of a role's argument (its plain text and code pieces). -/
def roleText (args : Array Syntax) : DocElabM String := do
  return inlineToString (← getEnv) (mkNullNode args)

/-- A file (or folder) of the repository, which must exist when the page is built:
`{file}` followed by the path in backticks. -/
@[role]
def file : RoleExpanderOf Unit
  | (), args => do
    let path ← roleText args
    unless safeRepoPath path do throwError "{path}: not a path inside the repository"
    unless ← ((← repoRoot) / path).pathExists do
      throwError "{path}: no such file or folder in the repository"
    ``(Inline.other (Inline.repoFile $(quote path)) #[Inline.code $(quote path)])

/-- A module name linked to its page in the API reference (tag `api-<module>`): `{api}`
followed by the name in backticks. The module must be part of the library. -/
@[role]
def api : RoleExpanderOf Unit
  | (), args => do
    let name ← roleText args
    unless (← getEnv).header.moduleNames.contains name.toName do
      throwError "{name} is not a module the manual imports"
    ``(Inline.other (Verso.Genre.Manual.Inline.ref $(quote ("api-" ++ name)) none none)
        #[Inline.code $(quote name)])

/-! ## Quoting the repository's documents -/

/-- `s` escaped for HTML text and attribute values. -/
def esc (s : String) : String := LeAnTeX.Backend.escape s

mutual
/-- Markdown inline text as HTML (links point into the repository when relative). -/
partial def mdText : MD4Lean.Text → String
  | .normal s => esc s
  | .nullchar => ""
  | .br _ => "<br/>"
  | .softbr _ => "\n"
  | .entity e => e
  | .em t => "<em>" ++ mdTexts t ++ "</em>"
  | .strong t => "<strong>" ++ mdTexts t ++ "</strong>"
  | .u t => "<u>" ++ mdTexts t ++ "</u>"
  | .a href _ _ t =>
    let h := attrText href
    let h := if h.startsWith "https://" || h.startsWith "#" then h
      else s!"{repositoryUrl}/blob/main/{h}"
    s!"<a href=\"{esc h}\">" ++ mdTexts t ++ "</a>"
  | .img _ _ alt => mdTexts alt
  | .code s => "<code>" ++ esc (String.join s.toList) ++ "</code>"
  | .del t => "<del>" ++ mdTexts t ++ "</del>"
  | .latexMath s => esc ("$" ++ String.join s.toList ++ "$")
  | .latexMathDisplay s => esc ("$$" ++ String.join s.toList ++ "$$")
  | .wikiLink _ t => mdTexts t

/-- A run of Markdown inline text as HTML. -/
partial def mdTexts (ts : Array MD4Lean.Text) : String := String.join (ts.toList.map mdText)

/-- An attribute's text (a link target). -/
partial def attrText (a : Array MD4Lean.AttrText) : String :=
  String.join <| a.toList.map fun
    | .normal s => s
    | .entity e => e
    | .nullchar => ""
end

/-- A Markdown block as HTML (headings one level lower than written, so that a quoted section
sits below the page's own headings). -/
partial def mdBlock : MD4Lean.Block → String
  | .p t => "<p>" ++ mdTexts t ++ "</p>\n"
  | .ul _ _ items => "<ul>" ++ String.join (items.toList.map fun li =>
      "<li>" ++ String.join (li.contents.toList.map mdBlock) ++ "</li>") ++ "</ul>\n"
  | .ol _ start _ items => s!"<ol start=\"{start}\">" ++ String.join (items.toList.map fun li =>
      "<li>" ++ String.join (li.contents.toList.map mdBlock) ++ "</li>") ++ "</ol>\n"
  | .hr => "<hr/>\n"
  | .header n t => s!"<h{min 6 (n + 2)}>" ++ mdTexts t ++ s!"</h{min 6 (n + 2)}>\n"
  | .code _ _ _ ls => "<pre class=\"ltx-quote-code\">" ++ esc (String.join ls.toList) ++ "</pre>\n"
  | .html ls => esc (String.join ls.toList)
  | .blockquote bs => "<blockquote>" ++ String.join (bs.toList.map mdBlock) ++ "</blockquote>\n"
  | .table head body =>
    let row (tag : String) (cells : Array (Array MD4Lean.Text)) : String :=
      "<tr>" ++ String.join (cells.toList.map fun c => s!"<{tag}>" ++ mdTexts c ++ s!"</{tag}>")
        ++ "</tr>"
    "<div class=\"ltx-table-wrap\"><table class=\"ltx-quote-table\"><thead>" ++ row "th" head ++
      "</thead><tbody>" ++ String.join (body.toList.map (row "td")) ++ "</tbody></table></div>\n"

/-- The lines of the section of Markdown text `md` under the heading `heading` (any level), up
to the next heading of the same or a higher level; `none` when there is no such heading, when
there is more than one, or when the section holds nothing but blank lines. -/
def sectionLines (md heading : String) : Option (List String) := do
  let ls := md.splitOn "\n"
  let level (l : String) : Nat := (l.toList.takeWhile (· == '#')).length
  let isIt (l : String) : Bool := level l > 0 && (l.drop (level l)).trimAscii.toString == heading
  guard ((ls.filter isIt).length == 1)
  let idx ← ls.findIdx? isIt
  let lvl := level ls[idx]!
  let rest := ls.drop (idx + 1)
  let body := rest.takeWhile fun l => let k := level l; k == 0 || k > lvl
  guard (body.any fun l => !l.trimAscii.isEmpty)
  return body

block_extension Block.rawHtml (html : String) where
  data := Json.str html
  traverse _ _ _ := pure none
  toTeX := some fun _ _ _ _ _ => pure .empty
  toHtml := some fun _ _ _ data _ => do
    match data with
    | .str h => pure (.raw h)
    | _ => pure .empty

/-- The arguments of `quoteSection`: the file and the heading. -/
structure QuoteArgs where
  /-- The Markdown file, relative to the repository's root. -/
  file : String
  /-- The heading whose section is quoted. -/
  heading : String

instance : FromArgs QuoteArgs DocElabM where
  fromArgs := QuoteArgs.mk <$> .positional `file .string <*> .positional `heading .string

/-- The HTML of a section of a Markdown file of the repository. -/
def quoteHtml (file heading : String) : DocElabM String := do
  let md ← readRepoFile file
  let some body := sectionLines md heading
    | throwError "{file} has no heading \"{heading}\", more than one, or an empty section"
  let flags := MD4Lean.MD_FLAG_TABLES ||| MD4Lean.MD_FLAG_NOHTML
  let some doc := MD4Lean.parse ("\n".intercalate body) flags
    | throwError "the section \"{heading}\" of {file} is not Markdown MD4Lean reads"
  return String.join (doc.blocks.toList.map mdBlock)

/-- `{quoteSection "FILE" "HEADING"}`: the section under that heading of a Markdown file of the
repository, rendered when the manual is built, in a frame that names its source. -/
@[block_command]
def quoteSection : BlockCommandOf QuoteArgs
  | {file, heading} => do
    let body ← quoteHtml file heading
    let href := s!"{repositoryUrl}/blob/main/{file}"
    let html := s!"<div class=\"ltx-quote\"><div class=\"ltx-quote-source\">From \
      <a href=\"{esc href}\"><code>{esc file}</code></a>, section “{esc heading}”, as \
      committed</div>{body}</div>"
    ``(Block.other (Block.rawHtml $(quote html)) #[])

/-- The argument of `fileText`: the file. -/
structure FileArgs where
  /-- The file, relative to the repository's root. -/
  file : String

instance : FromArgs FileArgs DocElabM where
  fromArgs := FileArgs.mk <$> .positional `file .string

/-- `{fileText "FILE"}`: a text file of the repository in full, as preformatted text. -/
@[block_command]
def fileText : BlockCommandOf FileArgs
  | {file} => do
    let text ← readRepoFile file
    let html := s!"<details class=\"ltx-licence\"><summary><code>{esc file}</code> \
      ({(text.splitOn "\n").length} lines)</summary><pre>{esc text}</pre></details>"
    ``(Block.other (Block.rawHtml $(quote html)) #[])

/-- `{tsvTable "FILE"}`: a tab-separated file of the repository as a table, its first line the
header. -/
@[block_command]
def tsvTable : BlockCommandOf FileArgs
  | {file} => do
    let text ← readRepoFile file
    let rows := (text.splitOn "\n").filter (!·.trimAscii.isEmpty)
    let some head := rows.head? | throwError "{file} is empty"
    let cells (tag l : String) : String :=
      "<tr>" ++ String.join ((l.splitOn "\t").map fun c => s!"<{tag}>{esc c}</{tag}>") ++ "</tr>"
    let html := s!"<div class=\"ltx-quote\"><div class=\"ltx-quote-source\">From \
      <code>{esc file}</code>, as committed</div><div class=\"ltx-table-wrap\"><table \
      class=\"ltx-quote-table\"><thead>{cells "th" head}</thead><tbody>\
      {String.join ((rows.drop 1).map (cells "td"))}</tbody></table></div></div>"
    ``(Block.other (Block.rawHtml $(quote html)) #[])

/-! ## Theorems -/

/-- The modules that hold the library's theorems. -/
def proofModules : List Name :=
  [`LeAnTeX.Backend.Proofs, `LeAnTeX.Text.Proofs, `LeAnTeX.Doc.Proofs, `LeAnTeX.TeXMath.Proofs]

/-- The axioms a theorem may rest on: Lean's three standard ones. -/
def standardAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

/-- `{axiomTable}`: every theorem of `proofModules` with its axioms, in source order. Fails when
one rests on another axiom, or when there is none. -/
@[block_command]
def axiomTable : BlockCommandOf Unit
  | () => do
    let env ← getEnv
    let mut rows := ""
    let mut count := 0
    for mod in proofModules do
      let some idx := env.getModuleIdx? mod | throwError "{mod} is not imported"
      let mut thms : Array (Name × Nat) := #[]
      for (n, ci) in env.constants.map₁.toList do
        unless env.getModuleIdxFor? n == some idx do continue
        unless ci matches .thmInfo _ do continue
        if n.isInternalDetail || Linter.isDeprecated env n then continue
        -- the equation lemmas Lean generates for a definition (`f.eq_1`, `f.eq_def`,
        -- `f.eq_unfold`: names reserved for them, under a definition); a hand-written theorem
        -- of any other name, `eq_` at its start or not, is listed
        if let .str parent last := n then
          if Meta.isEqnLikeSuffix last && (env.find? parent).any (·.isDefinition) then continue
        let line := (← findDeclarationRanges? n).map (·.range.pos.line) |>.getD 0
        thms := thms.push (n, line)
      for (n, _) in thms.qsort (fun a b => a.2 < b.2) do
        let axs ← collectAxioms n
        for a in axs do
          unless standardAxioms.contains a do
            throwError "{n} rests on the axiom {a}"
        count := count + 1
        let shown := ", ".intercalate (axs.toList.map (s!"<code>{esc ·.toString}</code>"))
        rows := rows ++ s!"<tr><td><code>{esc n.toString}</code></td><td>\
          {if axs.isEmpty then "none" else shown}</td></tr>"
    if count == 0 then throwError "no theorems found in {proofModules}"
    let html := s!"<div class=\"ltx-table-wrap\"><table class=\"ltx-quote-table\"><thead><tr>\
      <th>Theorem</th><th>Axioms</th></tr></thead><tbody>{rows}</tbody></table></div>"
    ``(Block.other (Block.rawHtml $(quote html)) #[])

end LeAnTeXManual
