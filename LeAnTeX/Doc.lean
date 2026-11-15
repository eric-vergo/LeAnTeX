/-
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
-/
import LeAnTeX.Doc.VList
import LeAnTeX.Doc.PageBuilder
import LeAnTeX.Doc.State
import LeAnTeX.Doc.Class
import LeAnTeX.Doc.Counters
import LeAnTeX.Doc.Lists
import LeAnTeX.Doc.Tables
import LeAnTeX.Doc.Commands
import LeAnTeX.Doc.Environments
import LeAnTeX.Doc.Output
import LeAnTeX.Doc.Front

/-!
# The document layer

LaTeX documents (the `article` class) to pages: vertical lists, TeX's page builder, LaTeX's
output routine, structure, counters, references and environments (`docs/documents.md`).
-/
