/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/

/-!
# The manual's stylesheet

The rules for the manual's own elements (`LeAnTeXManual.Meta`): samples on a white sheet (the
pictures are black on transparent, as TeX's output is black on paper), quoted sections of the
repository's documents in a frame that names the file, their tables, the licence texts and the
footer.
-/

namespace LeAnTeXManual

/-- The stylesheet `Main.lean` adds to every page. -/
def css : String := r#"
.ltx-sample { margin: 1.25em 0; }
.ltx-sample .ltx-paper {
  background: #fff; border: 1px solid #d0d0d0; border-radius: 4px; padding: 0.75em;
  display: flex; flex-wrap: wrap; gap: 1em; align-items: flex-start; overflow-x: auto;
}
.ltx-sample.ltx-pages .ltx-paper { background: #ececec; }
.ltx-sample.ltx-pages .ltx-picture { background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.25);
  max-width: min(100%, 460px); height: auto; }
.ltx-picture { max-width: 100%; height: auto; }
.ltx-sample figcaption { font-size: 0.9em; color: #555; margin-top: 0.4em; }
.ltx-frame { width: 100%; border: 1px solid #d0d0d0; border-radius: 4px; background: #fff; }
.ltx-quote { border-left: 3px solid #b8c4d6; padding: 0.2em 0 0.2em 1em; margin: 1.25em 0; }
.ltx-quote-source { font-size: 0.85em; color: #555; margin-bottom: 0.5em; }
.ltx-table-wrap { overflow-x: auto; }
.ltx-quote-table { border-collapse: collapse; font-size: 0.9em; }
.ltx-quote-table th, .ltx-quote-table td { border: 1px solid #ccc; padding: 0.3em 0.5em;
  vertical-align: top; text-align: left; }
.ltx-quote-table th { background: #f2f4f7; }
.ltx-quote-code, .ltx-licence pre { overflow-x: auto; font-size: 0.85em; }
.ltx-licence { margin: 0.75em 0; }
.ltx-licence summary { cursor: pointer; }
.ltx-licence pre { white-space: pre-wrap; background: #f7f7f7; padding: 0.75em; }
.ltx-footer { font-size: 0.85em; color: #666; margin: 3em 0 1em; }
.ltx-run { font-size: 0.85em; }
"#

end LeAnTeXManual
