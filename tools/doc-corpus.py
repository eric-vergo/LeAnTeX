#!/usr/bin/env python3
# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Writes the document corpus, corpus/doc/<name>.tex: small LaTeX documents (article class), each
# exercising one feature of the document layer or a few together. The prose is this file's own
# (FILLER), repeated where a document needs several pages. tools/doc-reference.sh records
# LuaLaTeX's answers for them into fixtures/doc/. Run from the repository root:
#     python3 -I tools/doc-corpus.py
# Hand-written documents (corpus/doc/*.tex not named here) are left alone.

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "corpus" / "doc"

# Prose for filling pages: plain sentences, no commands.
FILLER = [
    "A typesetting system takes a description of a document and decides where every character "
    "goes. It breaks paragraphs into lines, stacks the lines into pages and places headings, "
    "notes and figures where the reader expects them. Each of these steps follows rules that "
    "can be written down precisely, and a good program follows them exactly.",
    "Lines of a paragraph are chosen together rather than one at a time. The program looks at "
    "every way of breaking the paragraph and picks the one whose lines are spaced most evenly, "
    "avoiding hyphens on consecutive lines and very loose lines next to very tight ones.",
    "Pages are built one line at a time. As each line arrives the program measures how well the "
    "page would look if it ended there, and when adding more would only make it worse it stops "
    "and starts a new page. Penalties discourage breaks in awkward places, such as after the "
    "first line of a paragraph or before its last.",
    "Vertical space between paragraphs and around headings can stretch and shrink a little, so "
    "that a page whose lines do not exactly fill it can still be set with its last line at the "
    "bottom. The amount of stretch is small, and most of it goes where a reader will not notice.",
    "Notes at the foot of a page are collected separately from the main text. They take space "
    "from the page they appear on, and when there are too many some of them move to the next "
    "page, keeping their order and their numbers.",
    "Figures and tables float. Instead of appearing exactly where they are mentioned they are "
    "placed at the top or bottom of a page, or on a page of their own, following preferences "
    "the author gives and limits the document class sets.",
]


def para(i):
    """The i-th filler paragraph (cycling)."""
    return FILLER[i % len(FILLER)]


def paras(start, n):
    """n filler paragraphs from the start-th, separated by blank lines."""
    return "\n\n".join(para(start + k) for k in range(n))


def doc(body, options="", preamble=""):
    """A whole document around a body."""
    opt = f"[{options}]" if options else ""
    pre = (preamble.strip() + "\n") if preamble.strip() else ""
    return f"\\documentclass{opt}{{article}}\n{pre}\\begin{{document}}\n{body.strip()}\n\\end{{document}}\n"


DOCS = {}

DOCS["sections-levels"] = doc(r"""
\section{First section}
Some text.
\subsection{First subsection}
Some text.
\subsubsection{First subsubsection}
Some text.
\paragraph{A paragraph heading} Text runs on after a paragraph heading.
\subparagraph{A subparagraph heading} Text runs on after it too.
\section*{Starred section}
\subsection*{Starred subsection}
Text.
\subsection{Second subsection}
Text after it.
""")

DOCS["sections-pages"] = doc("\n".join(
    f"\\section{{Section {k + 1}}}\n{paras(k, 3)}\n\\subsection{{Details}}\n{paras(k + 2, 2)}"
    for k in range(4)))

DOCS["title"] = doc(r"""
\title{On the Placement of Lines}
\author{A. Writer \and B. Reader}
\date{1 January 2025}
\maketitle
\section{Start}
""" + paras(0, 2))

DOCS["title-thanks"] = doc(r"""
\title{A Title\thanks{With a note.}}
\author{An Author}
\date{}
\maketitle
""" + paras(1, 1))

DOCS["toc"] = doc(r"""
\tableofcontents
\section{Alpha}
Text.
\subsection{Alpha one}
Text.
\subsection{Alpha two}
Text.
\section{Beta}
Text.
\subsubsection{Beta deep}
Text.
\section*{Gamma}
Text.
""")

DOCS["toc-pages"] = doc(r"""
\tableofcontents
\newpage
""" + "\n".join(f"\\section{{Part {k + 1}}}\n{paras(k, 4)}" for k in range(5)))

DOCS["counters"] = doc(r"""
\newcounter{thing}
\setcounter{thing}{3}
Thing \thething. \stepcounter{thing}Thing \thething.
\addtocounter{thing}{10}Thing \arabic{thing}, \roman{thing}, \Roman{thing},
\alph{thing}, \Alph{thing}, \fnsymbol{footnote}.
\newcounter{sub}[thing]
\setcounter{sub}{2}\stepcounter{thing}Sub \arabic{sub}.
\renewcommand{\thething}{[\Roman{thing}]}Thing \thething.
\setcounter{section}{4}
\section{Fifth}
Value \the\value{section}.
""")

DOCS["refs"] = doc(r"""
\section{One}\label{sec:one}
See Section~\ref{sec:two} on page~\pageref{sec:two} and equation~\eqref{eq:a}.
\begin{equation}\label{eq:a}
a = b
\end{equation}
\subsection{One A}\label{sec:onea}
""" + paras(0, 6) + r"""
\section{Two}\label{sec:two}
Back to Section~\ref{sec:one} and Subsection~\ref{sec:onea}; a missing one: \ref{nowhere}.
""", preamble=r"\usepackage{amsmath}")

DOCS["lengths"] = doc(r"""
\setlength{\parindent}{2em}
\setlength{\parskip}{6pt plus 2pt}
""" + paras(0, 2) + r"""

\addtolength{\parindent}{-1em}
""" + paras(2, 2))

DOCS["options-11pt"] = doc(r"\section{Eleven}" + "\n" + paras(0, 3), options="11pt")
DOCS["options-12pt"] = doc(r"\section{Twelve}" + "\n" + paras(0, 3), options="12pt")
DOCS["options-a4"] = doc(r"\section{Paper}" + "\n" + paras(0, 8), options="a4paper")
DOCS["options-12pt-a4"] = doc(r"\section{Both}" + "\n" + paras(0, 8), options="12pt,a4paper")

DOCS["itemize"] = doc(r"""
Before the list.
\begin{itemize}
\item First item of the list, which is long enough to run over more than one line of text so
the indentation of the second line shows.
\item Second item.
\begin{itemize}
\item Nested.
\begin{itemize}
\item Third level.
\begin{itemize}
\item Fourth level.
\end{itemize}
\end{itemize}
\end{itemize}
\item[$\star$] A custom label.
\end{itemize}
After the list.
""")

DOCS["enumerate"] = doc(r"""
\begin{enumerate}
\item One.\label{it:one}
\item Two.
\begin{enumerate}
\item Two a.\label{it:twoa}
\begin{enumerate}
\item Two a i.
\begin{enumerate}
\item Two a i A.
\end{enumerate}
\end{enumerate}
\end{enumerate}
\item Three.
\end{enumerate}
Items \ref{it:one} and \ref{it:twoa}.
""")

DOCS["description"] = doc(r"""
\begin{description}
\item[Apple] A fruit that grows on trees and is eaten raw or cooked; this description runs
over a line.
\item[Banana] Another fruit.
\item Without a label.
\end{description}
""")

DOCS["quote"] = doc(para(0) + r"""
\begin{quote}
""" + para(1) + r"""
\end{quote}
""" + para(2) + r"""
\begin{quotation}
""" + paras(3, 2) + r"""
\end{quotation}
Done.
""")

DOCS["center"] = doc(r"""
\begin{center}
Centred text.\\ A second centred line.
\end{center}
\begin{flushleft}
Flush left text that is long enough to break onto a second line so the ragged right edge
shows clearly here.
\end{flushleft}
\begin{flushright}
Flush right.\\ Two.
\end{flushright}
""")

DOCS["verbatim"] = doc(r"""
Inline \verb|\verb| and \verb+a_b{c}+ text.
\begin{verbatim}
def f(x):
    return x * 2   # spaces kept
\end{verbatim}
After.
""")

DOCS["abstract"] = doc(r"""
\title{With an Abstract}
\author{Someone}
\date{2 February 2025}
\maketitle
\begin{abstract}
""" + para(0) + r"""
\end{abstract}
\section{Body}
""" + para(1))

DOCS["equation"] = doc(para(0) + r"""
\begin{equation}
x^2 + y^2 = z^2 \label{eq:p}
\end{equation}
Then an unnumbered display:
\begin{equation*}
\int_0^1 f(x)\,dx
\end{equation*}
and \eqref{eq:p} again, and display math
\[ a + b \]
with text after it.
""", preamble=r"\usepackage{amsmath}")

DOCS["align"] = doc(r"""
Some equations:
\begin{align}
a &= b + c \\
d &= e
\end{align}
and
\begin{align*}
f &= g
\end{align*}
\begin{gather}
p = q
\end{gather}
\begin{multline}
x = y
\end{multline}
End.
""", preamble=r"\usepackage{amsmath}")

DOCS["newenvironment"] = doc(r"""
\newenvironment{boxed}{\begin{quote}\itshape}{\end{quote}}
\newenvironment{named}[1]{\par\noindent\textbf{#1.}}{\par}
\begin{boxed}
Inside the new environment.
\end{boxed}
\begin{named}{Note}
A named block.
\end{named}
""")

DOCS["theorem"] = doc(r"""
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{defn}{Definition}[section]
\section{Results}
\begin{theorem}\label{thm:a}
Every line is a box.
\end{theorem}
\begin{lemma}[Stacking]
Boxes stack.
\end{lemma}
\begin{defn}
A page is a box.
\end{defn}
By Theorem~\ref{thm:a}.
""")

DOCS["theorem-amsthm"] = doc(r"""
\newtheorem{theorem}{Theorem}
\theoremstyle{definition}
\newtheorem{definition}{Definition}
\section{Results}
\begin{theorem}
Every line is a box.
\end{theorem}
\begin{proof}
Clear from the construction.
\end{proof}
\begin{definition}
A page is a box.
\end{definition}
\begin{proof}[Proof of everything]
Trivial.
\end{proof}
""", preamble=r"\usepackage{amsthm}")

DOCS["footnotes"] = doc(r"""
Text with a note.\footnote{The first note.} More text with another\footnote{A second, longer
note that runs over more than one line at the foot of the page to show how notes are set.}
and an end.
""" + paras(0, 2))

DOCS["emph"] = doc(r"""
Plain \emph{emphasised \emph{inner} again} plain. \textit{Italic \emph{upright} italic.}
\textbf{Bold \emph{bold italic}.} \textsc{Small Caps} and \texttt{typewriter}.
""")

DOCS["accents"] = doc(r"""
Caf\'e, na\"ive, h\^otel, \`a la, ma\~nana, gar\c{c}on, \=a, \.z, \u{g}, \v{s}, \H{o},
\r{a}, \k{e}, \'{\i}, \"{\i}, \aa, \AA, \ae, \oe, \o, \ss, \l.
""")

DOCS["rules"] = doc(r"""
A rule \rule{2cm}{0.4pt} in text and a raised one \rule[1ex]{1cm}{2pt}.

\noindent\rule{\textwidth}{1pt}

\hrule
After an hrule. A strut \rule{0pt}{20pt}tall.
""")

DOCS["tabular"] = doc(r"""
\begin{tabular}{lcr}
left & centre & right \\
a & b & c \\
\end{tabular}

\begin{tabular}{|l|c|r|}
\hline
A & B & C \\
\hline
one & two & three \\
\hline
\end{tabular}
""")

DOCS["tabular-multi"] = doc(r"""
\begin{center}
\begin{tabular}{|l|p{3cm}|r|}
\hline
\multicolumn{3}{|c|}{A heading over three columns} \\
\hline
x & a paragraph column that wraps over lines & 1 \\
y & short & 22 \\
\hline
\end{tabular}
\end{center}
""")

DOCS["pages-long"] = doc(paras(0, 18))

DOCS["newpage"] = doc(para(0) + r"""
\newpage
""" + para(1) + r"""
\clearpage
""" + para(2) + r"""
\pagebreak
""" + para(3))

DOCS["skips"] = doc(para(0) + r"""
\smallskip
""" + para(1) + r"""
\medskip
""" + para(2) + r"""
\bigskip
""" + para(3) + r"""
\vspace{1cm}
""" + para(4) + r"""
\vfill
Last line at the bottom.
""")

DOCS["widows"] = doc(paras(0, 13) + r"""

""" + para(2) + " " + para(3))

DOCS["nopagebreak"] = doc(paras(0, 9) + r"""
\nopagebreak
""" + paras(3, 3))

DOCS["footnotes-pages"] = doc("\n\n".join(
    para(k) + f"\\footnote{{Note {k + 1}: " + para(k + 3) + "}" for k in range(9)))

DOCS["float-top"] = doc(para(0) + r"""
\begin{figure}[t]
\centering
\rule{4cm}{2cm}
\caption{A figure at the top.}\label{fig:t}
\end{figure}
""" + paras(1, 2) + r"""
Figure~\ref{fig:t} is above.
""")

DOCS["float-here"] = doc(para(0) + r"""
\begin{figure}[h]
\centering
\rule{3cm}{1cm}
\caption{Here.}
\end{figure}
""" + para(1) + r"""
\begin{table}[h]
\centering
\begin{tabular}{ll}
a & b \\
\end{tabular}
\caption{A table here.}
\end{table}
""" + para(2))

DOCS["float-bottom"] = doc(para(0) + r"""
\begin{figure}[b]
\centering
\rule{4cm}{1cm}
\caption{At the bottom.}
\end{figure}
""" + paras(1, 2))

DOCS["float-page"] = doc(para(0) + r"""
\begin{figure}[p]
\centering
\rule{4cm}{10cm}
\caption{On a page of floats.}
\end{figure}
""" + paras(1, 3))

DOCS["float-default"] = doc(paras(0, 3) + r"""
\begin{figure}
\centering
\rule{5cm}{3cm}
\caption{Default placement.}\label{fig:d}
\end{figure}
""" + paras(3, 8) + r"""
\begin{table}
\centering
\begin{tabular}{|c|c|}
\hline
1 & 2 \\
\hline
\end{tabular}
\caption{A table.}
\end{table}
See Figure~\ref{fig:d}.
""")

DOCS["pagestyle-empty"] = doc(r"\pagestyle{empty}" + "\n" + paras(0, 12))

DOCS["thispagestyle"] = doc(r"\thispagestyle{empty}" + "\n" + paras(0, 12))

DOCS["article"] = doc(r"""
\newtheorem{theorem}{Theorem}
\title{Pages from Lines}
\author{A. Writer}
\date{3 March 2025}
\maketitle
\begin{abstract}
""" + para(0) + r"""
\end{abstract}
\tableofcontents
\section{Introduction}\label{sec:intro}
""" + para(1) + r"""\footnote{""" + para(4) + r"""}
\begin{itemize}
\item Lines are chosen together.
\item Pages are built one line at a time.
\end{itemize}
\section{Results}\label{sec:results}
\begin{theorem}\label{thm:main}
Every page is a box of lines.
\end{theorem}
\begin{proof}
By construction, see Section~\ref{sec:intro}.
\end{proof}
""" + para(2) + r"""
\begin{table}[ht]
\centering
\begin{tabular}{|l|r|}
\hline
Step & Count \\
\hline
Lines & 12 \\
Pages & 2 \\
\hline
\end{tabular}
\caption{Counts.}\label{tab:counts}
\end{table}
\begin{figure}[ht]
\centering
\includegraphics[width=4cm]{images/square.png}
\caption{A picture.}\label{fig:pic}
\end{figure}
Table~\ref{tab:counts} and Figure~\ref{fig:pic} on page~\pageref{fig:pic}; Theorem~\ref{thm:main}.
\subsection{More}
""" + paras(3, 3), preamble=r"\usepackage{amsthm}" + "\n" + r"\usepackage{graphicx}")

DOCS["mixed"] = doc(r"""
\section{Lists and notes}
""" + para(0) + r"""
\begin{enumerate}
\item An item with a note.\footnote{The note.}
\item An item with a quote:
\begin{quote}
Quoted.
\end{quote}
\end{enumerate}
\begin{figure}[t]
\centering\rule{2cm}{2cm}
\caption{A square.}
\end{figure}
""" + paras(1, 5))


def main():
    """Writes every document of DOCS into corpus/doc/."""
    OUT.mkdir(parents=True, exist_ok=True)
    for name, text in sorted(DOCS.items()):
        (OUT / f"{name}.tex").write_text(text, encoding="utf-8")
    print(f"doc-corpus: {len(DOCS)} documents")


if __name__ == "__main__":
    main()
