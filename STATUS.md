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

## Next

1. Fix the remaining mismatches listed in `parity/REPORT.md`.
2. README, THIRD-PARTY notices, style pass, `lake build --wfail`.

## Open questions for the owner

1. The Noperthedron blueprint corpus: the blueprint repository states no licence (the
   formalisation it wraps is Apache-2.0). The corpus is kept local and ignored by git until
   the owner says whether it may be committed.

## How to resume

- KaTeX 0.19.1 source (sparse clone): `~/ideil-scratch/katex-0.19.1` (outside the repository).
- Reference renderer: a built `katex.min.js` 0.19.1, passed to `tools/record.mjs`.
