/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.Commands

/-!
# Graphics

`\includegraphics[keys]{path}` (with the `graphicx` package): a PNG or SVG file as a box in
the paragraph, its bottom on the baseline.

* **Paths are untrusted.** A path must be relative, without `..`, `.` or empty segments (so
  each file has one spelling), of letters, digits, `.`, `_`, `-` and `/` only, at most 255
  characters; the caller's `Settings.images`
  decides which files exist (the renderer reads them inside one directory and refuses links
  that leave it). Files larger than `Settings.maxImage` are refused, and so is a document whose
  distinct images together have more than `Settings.maxImagesTotal` bytes.
* **Natural size**: a PNG's pixels as big points (72 per inch, as LuaTeX takes a PNG without
  a resolution; a `pHYs` resolution is not read), an SVG's `width` and `height` on its root
  element (in `px` at 96 per inch, `pt`, `bp`, `mm`, `cm`, `in`, or no unit as `px`), else
  its `viewBox`'s.
* **Keys**: `width`, `height` (one keeps the aspect ratio; both stretch it), `scale`; other
  keys are an error.
* **Output**: an image item (`Item.image`) with the image's id in the document and the file as
  a `data:` URL (`image/png` or `image/svg+xml`, base64). Each file is read and encoded once per
  document, and every use shares the id and the string; the SVG and HTML back ends write the
  data once per output file, as an `<image>` in `<defs>`, and draw each use with `<use>`. The
  SVG file is drawn as an image, so its scripts never run in the document.
-/

namespace LeAnTeX.Text.Typeset

open LeAnTeX.Doc

/-- Whether a path may be asked for (see the module docstring). -/
def safeImagePath (p : String) : Bool :=
  p.length > 0 && p.length ≤ 255 && !p.startsWith "/" &&
    p.all (fun c => c.isAlphanum || c == '.' || c == '_' || c == '-' || c == '/') &&
    !((p.splitOn "/").any fun seg => seg == ".." || seg == "." || seg == "")

/-- Base64 of bytes (RFC 4648, with padding). -/
def base64 (b : ByteArray) : String := Id.run do
  let tbl := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toList.toArray
  let ch := fun (n : Nat) => tbl[n % 64]?.getD 'A'
  let mut out := ""
  let n := b.size
  for k in [0:(n + 2) / 3] do
    let i := 3 * k
    let a := (b[i]?).map (·.toNat) |>.getD 0
    let c := (b[i + 1]?).map (·.toNat) |>.getD 0
    let d := (b[i + 2]?).map (·.toNat) |>.getD 0
    let v := a * 65536 + c * 256 + d
    out := out.push (ch (v / 262144)) |>.push (ch (v / 4096))
    out := out.push (if i + 1 < n then ch (v / 64) else '=')
    out := out.push (if i + 2 < n then ch v else '=')
  return out

/-- A PNG's size in pixels, from its `IHDR` chunk. -/
def pngSize (b : ByteArray) : Option (Nat × Nat) := do
  let sig : List UInt8 := [137, 80, 78, 71, 13, 10, 26, 10]
  if b.size < 24 || (List.range 8).any (fun i => b[i]? != sig[i]?) then none
  let be := fun (i : Nat) => (List.range 4).foldl (init := 0) fun acc k =>
    acc * 256 + ((b[i + k]?).map (·.toNat)).getD 0
  let w := be 16
  let h := be 20
  if w == 0 || h == 0 || w > 100000 || h > 100000 then none
  return (w, h)

/-- A length in an SVG attribute as sp (see the module docstring). -/
def svgLength (s : String) : Option Int := do
  let s := s.trimAscii.toString
  let num := s.takeWhile (fun c => c.isDigit || c == '.')
  let unit := (s.drop num.toString.length).toString.trimAscii.toString
  let parts := num.toString.splitOn "."
  let whole ← (parts[0]?.getD "0").toNat?
  let fracDigits := (parts[1]?.getD "").toList.take 6
  let frac := fracDigits.foldl (fun a c => a * 10 + (c.toNat - '0'.toNat)) 0
  let scale := 10 ^ fracDigits.length
  -- sp per unit, as a fraction num/den of sp
  let (n, d) : Nat × Nat := match unit with
    | "" | "px" => (7227 * 65536, 9600)
    | "pt" => (7227 * 65536, 7200)
    | "bp" => (7227 * 65536, 7200)
    | "in" => (7227 * 65536, 100)
    | "cm" => (7227 * 65536, 254)
    | "mm" => (7227 * 65536, 2540)
    | _ => (0, 1)
  if n == 0 || whole > 100000 then none
  return ((whole * scale + frac) * n / (d * scale) : Nat)

/-- The value of an attribute in the first `<svg` tag of a text (bounded scan). -/
def svgAttr (txt : String) (name : String) : Option String := do
  let parts := txt.splitOn "<svg"
  let tag ← parts[1]?
  let tag := (tag.splitOn ">")[0]?.getD ""
  let afterName ← (tag.splitOn (" " ++ name ++ "=\""))[1]?
  (afterName.splitOn "\"")[0]?

/-- An SVG's natural size (see the module docstring). -/
def svgSize (b : ByteArray) : Option (Int × Int) := do
  let txt ← String.fromUTF8? b
  let txt := txt.take 65536 |>.toString
  match (svgAttr txt "width").bind svgLength, (svgAttr txt "height").bind svgLength with
  | some w, some h => return (w, h)
  | _, _ =>
    let vb ← svgAttr txt "viewBox"
    let ns := (vb.splitOn " ").filter (· ≠ "")
    let w ← (ns[2]?).bind svgLength
    let h ← (ns[3]?).bind svgLength
    return (w, h)

/-- `\includegraphics[keys]{path}` (see the module docstring). -/
def includeGraphics (at_ : Tok) : M Unit := do
  if !(← docSt).packages.any (fun p => p == "graphicx" || p == "graphics") then
    failAt at_ "Undefined control sequence \\includegraphics (load graphicx)"
  let keys ← readOptional?
  let path ← readWord at_
  if !safeImagePath path then failAt at_ s!"Image path not allowed: {path.take 80}"
  let (cfg, _) ← read
  let (id, href, nat) ← match (← docSt).images[path]? with
    | some (id, href, w, h) => pure (id, href, w, h)
    | none =>
      let some bytes := cfg.images path | failAt at_ s!"File '{path}' not found"
      if bytes.size > cfg.maxImage then failAt at_ s!"Image '{path}' too large"
      let total := (← docSt).imageBytes + bytes.size
      if total > cfg.maxImagesTotal then
        failAt at_ s!"Images too large: the document's images have more than \
          {cfg.maxImagesTotal} bytes"
      let (kind, nat) ← match pngSize bytes with
        | some (w, h) =>
          let bp := fun (n : Nat) => ((n * 7227 * 65536 / 7200 : Nat) : Int)
          pure ("image/png", bp w, bp h)
        | none => match svgSize bytes with
          | some (w, h) => pure ("image/svg+xml", w, h)
          | none => failAt at_ s!"Image '{path}' is neither a PNG nor an SVG with a size"
      let id := s!"img{(← docSt).images.size + 1}"
      let href := s!"data:{kind};base64," ++ base64 bytes
      modifyDoc fun d => { d with images := d.images.insert path (id, href, nat.1, nat.2),
                                  imageBytes := total }
      pure (id, href, nat)
  let (nw, nh) := nat
  let mut w : Option Int := none
  let mut h : Option Int := none
  let mut scale : Option (Int × Int) := none
  for kv in ((keys.map tokText).getD "").splitOn "," do
    let kv := kv.trimAscii.toString
    if kv.isEmpty then continue
    match kv.splitOn "=" with
    | [k, v] =>
      let k := k.trimAscii.toString
      let v := v.trimAscii.toString
      if k == "width" || k == "height" then
        let saved := (← get).input
        modify fun s => { s with input := (textToks at_ v).reverse }
        let (d, _) ← readDimen at_
        modify fun s => { s with input := saved }
        if d ≤ 0 || d > 1073741823 then failAt at_ "Bad image size"
        if k == "width" then w := some d else h := some d
      else if k == "scale" then
        let ps := v.splitOn "."
        let whole := ((ps[0]?.getD "0").toNat?).getD 0
        let fr := (ps[1]?.getD "").take 4 |>.toString
        let fv := (fr ++ String.ofList (List.replicate (4 - fr.length) '0')).toNat?.getD 0
        scale := some ((whole * 10000 + fv : Nat), 10000)
      else failAt at_ s!"Unknown graphics key '{k}'"
    | _ => if kv != "keepaspectratio" then failAt at_ s!"Bad graphics option '{kv}'"
  let (fw, fh) := match w, h, scale with
    | some w, some h, _ => (w, h)
    | some w, none, _ => (w, if nw == 0 then 0 else nh * w / nw)
    | none, some h, _ => (if nh == 0 then 0 else nw * h / nh, h)
    | none, none, some (n, d) => (nw * n / d, nh * n / d)
    | none, none, none => (nw, nh)
  if fw > 1073741823 || fh > 1073741823 then failAt at_ "Image too large"
  let dl : DisplayList :=
    { width := ⟨fw⟩, height := ⟨fh⟩, depth := 0,
      items := #[.image id href 0 ⟨-fh⟩ ⟨fw⟩ ⟨fh⟩] }
  startParagraph
  push (.math fw fh 0 dl (Em.unit : Int))

end LeAnTeX.Text.Typeset
