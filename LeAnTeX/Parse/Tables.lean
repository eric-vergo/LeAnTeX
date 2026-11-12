/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import Std.Data.HashMap
import LeAnTeX.Data.Functions
import LeAnTeX.Data.Environments
import LeAnTeX.Data.Macros
import LeAnTeX.Data.Symbols
import LeAnTeX.Data.Unicode

/-!
# Lookup tables

The generated KaTeX tables of `LeAnTeX.Data` as hash maps, built once, for the parser and the
macro expander to look names up in.

## Main definitions

* `functions`, `environments`, `mathSymbols`, `textSymbols`, `builtinStringMacros`.
* `symbolsIn`: the symbol table of a mode.
* `unicodeSymbols`, `unicodeAccents`, `subSup`, `supportedCodepoint`: the Unicode data.

## References

* KaTeX's `src/functions.ts`, `src/environments.ts`, `src/symbols.ts`, `src/macros.ts` and the
  Unicode modules (MIT licence, see `LICENSE-KaTeX`).
-/

namespace LeAnTeX.Tables

open Std

/-- KaTeX's functions by name. -/
def functions : HashMap String FunctionSpec := HashMap.ofList Data.functionList.toList

/-- KaTeX's environments by name. -/
def environments : HashMap String EnvSpec := HashMap.ofList Data.environmentList.toList

/-- Math-mode symbols by name. -/
def mathSymbols : HashMap String SymbolInfo := HashMap.ofList Data.mathSymbolList.toList

/-- Text-mode symbols by name. -/
def textSymbols : HashMap String SymbolInfo := HashMap.ofList Data.textSymbolList.toList

/-- The symbol table of a mode. -/
def symbolsIn : Mode → HashMap String SymbolInfo
  | .math => mathSymbols
  | .text => textSymbols

/-- Built-in macros with a string body. -/
def builtinStringMacros : HashMap String String := HashMap.ofList Data.stringMacroList.toList

/-- Built-in macros KaTeX defines as functions. -/
def nativeMacros : HashSet String := HashSet.ofList Data.nativeMacroNames.toList

/-- Precomposed accented letters and their decomposition. -/
def unicodeSymbols : HashMap String String := HashMap.ofList Data.unicodeSymbolList.toList

/-- Combining accents: the text-mode and math-mode commands. -/
def unicodeAccents : HashMap String (String × Option String) :=
  HashMap.ofList Data.unicodeAccentList.toList

/-- Unicode sub- and superscripts: the plain character and whether it is a subscript. -/
def subSup : HashMap String (String × Bool) := HashMap.ofList Data.subSupList.toList

/-- Whether KaTeX supports a code point in text (`supportedCodepoint`). -/
def supportedCodepoint (cp : Nat) : Bool :=
  Data.supportedBlocks.any fun (a, b) => a ≤ cp && cp ≤ b

end LeAnTeX.Tables
