# Status

Resume notes for the work in progress. Updated after every step.

## State

- Repository skeleton, licences (`LICENSE` Apache-2.0, `LICENSE-KaTeX` MIT), lakefile, toolchain v4.35.0.
- Generated KaTeX 0.19.1 tables (`tools/gen-tables.mjs` → `LeAnTeX/Data/*.lean`, `parity/names.tsv`).
- Parser: lexer, macro expander (all 20 function-valued macros), parser, every function and
  environment handler (`LeAnTeX/Parse/`).
- Harness: corpora (`corpus/`, from `tools/harvest-katex.mjs`, `tools/extract-*.py`), KaTeX's
  answers (`fixtures/`, from `tools/record.mjs`), the differential test and parity report
  (`LeAnTeXTest/Main.lean`, `lake test`, `parity/`).

- Parity: 12,272 of 12,272 corpus cases match KaTeX 0.19.1 (trees, errors with full messages,
  warnings); every KaTeX name is parsed by at least one case or is internal.
- `lake build --wfail` clean (docstring linter on); `lake test` green; style checked with
  IDEiL's style checker run against this repository (0 violations).
- README, THIRD-PARTY.md written.

## Next

1. Layout core (later stages): boxes, metrics, display list; extend `tools/record.mjs` with
   KaTeX's layout numbers.

## Open questions for the owner

1. The Noperthedron blueprint corpus: the blueprint repository states no licence (the
   formalisation it wraps is Apache-2.0). The corpus is kept local and ignored by git until
   the owner says whether it may be committed.
2. `corpus/blueprint-rokicki.jsonl` names its source repository (the owner's own) and commit in
   its first line; whether that may stay once this repository is public.
3. The package name `leantex`, library and namespace `LeAnTeX`, and the licence wording of
   `THIRD-PARTY.md` are the obvious defaults, not decided by the owner.

## How to resume

- KaTeX 0.19.1 source: a checkout of tag `v0.19.1` outside the repository (the generators take its path).
- Reference renderer: a built `katex.min.js` 0.19.1, passed to `tools/record.mjs`.
