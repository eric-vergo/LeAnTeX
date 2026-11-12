# Third-party material

LeAnTeX's own code is released under the Apache License 2.0 (`LICENSE`). Parts of it are
derived from [KaTeX](https://github.com/KaTeX/KaTeX), version 0.19.1, which is released under
the MIT licence; its notice is reproduced in full in `LICENSE-KaTeX` and below. Each derived Lean
module names the KaTeX source files it follows in the *References* section of its module
docstring.

## Derived from KaTeX

| LeAnTeX | What | KaTeX source |
|---|---|---|
| `LeAnTeX/Data/*.lean` | tables generated from KaTeX's registries by `tools/gen-tables.mjs`: functions and their argument specifications, environments, built-in string macros, symbols (font, group, replacement), Unicode accents, precomposed letters, sub- and superscripts, supported script blocks | `src/functions/*.ts`, `src/environments/*.ts`, `src/macros.ts`, `src/symbols.ts`, `src/unicodeAccents.js`, `src/unicodeSymbols.js`, `src/unicodeSupOrSub.ts`, `src/unicodeScripts.ts` |
| `LeAnTeX/Spec.lean` | the shapes of the table entries | `src/defineFunction.ts`, `src/defineEnvironment.ts`, `src/symbols.ts`, `src/types/index.ts` |
| `LeAnTeX/Parse/Base.lean` | source locations, tokens, `ParseError` messages, settings, strict mode | `src/SourceLocation.ts`, `src/Token.ts`, `src/ParseError.ts`, `src/Settings.ts`, `src/strict.ts` |
| `LeAnTeX/Parse/Lexer.lean` | the lexer | `src/Lexer.ts` |
| `LeAnTeX/Parse/State.lean` | the macro namespace with grouping | `src/Namespace.ts`, `src/defineMacro.ts` |
| `LeAnTeX/Parse/MacroExpander.lean` | the macro expander and the function-valued built-in macros | `src/MacroExpander.ts`, `src/macros.ts` |
| `LeAnTeX/Parse/Node.lean`, `NodeJson.lean` | the parse node types and their JSON form | `src/types/nodes.ts` |
| `LeAnTeX/Parse/Ops.lean` | argument parsers, symbols, ligatures, URL protocol check | `src/Parser.ts`, `src/units.ts`, `src/utils.ts` |
| `LeAnTeX/Parse/Functions.lean` | the function handlers | `src/functions/*.ts`, `src/parseNode.ts`, `src/utils.ts` |
| `LeAnTeX/Parse/Environments.lean` | the environment handlers | `src/environments/array.ts`, `src/environments/cd.ts` |
| `LeAnTeX/Parse/Parser.lean` | the parser and `parseTree` | `src/Parser.ts`, `src/parseTree.ts` |
| `corpus/katex-spec.jsonl`, `katex-screenshots.jsonl`, `katex-support-table.jsonl` | formulas from KaTeX's tests and documentation | `test/*-spec.ts`, `test/screenshotter/ss_data.yaml`, `docs/support_table.md` |
| `fixtures/*.jsonl` | KaTeX's output (parse trees, errors, warnings) recorded by running KaTeX 0.19.1 | `dist/katex.min.js` |

## Other corpora

| File | Source | Licence |
|---|---|---|
| `corpus/mathlib.jsonl` | formulas in the doc comments of [Mathlib](https://github.com/leanprover-community/mathlib4) | Apache-2.0 |
| `corpus/blueprint-rokicki.jsonl` | formulas of a Verso blueprint site (source and commit in the file's first line) | Apache-2.0 |
| `corpus/katex-names.jsonl` | generated from KaTeX's name list | Apache-2.0 (this repository) |

## KaTeX's licence

```
The MIT License (MIT)

Copyright (c) 2013-2020 Khan Academy and other contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
