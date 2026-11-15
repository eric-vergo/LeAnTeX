# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Writes the text-mode corpora corpus/text/{paragraphs,words,boxes}.jsonl, the inputs that
# tools/tex-reference.sh typesets with real TeX to record fixtures/text/*.jsonl:
#   * paragraphs: public-domain and original prose at several line widths, fonts and sizes, and
#     cases for the parameters of TeX's line breaker (tolerance, looseness, emergency stretch,
#     ragged right, hyphen penalties) and for explicit glue, kerns, penalties and boxes;
#   * words: a fixed sample of Webster's Second International word list (the 1934 copyright has
#     lapsed; /usr/share/dict/web2 on BSD systems) and a list of words chosen for hyphenation;
#   * boxes: single-line boxes in every Latin Modern face LaTeX selects, for ligatures, kerning
#     and the glyph metrics an OpenType reader must reproduce.
# The sample is deterministic (every n-th word), so the corpus only changes when this file does.
#
# Usage, from the repository root: python3 -I tools/text-corpus.py [path/to/web2]

import json
import os
import sys

FROG = (
    "In olden times when wishing still helped one, there lived a king whose daughters were all "
    "beautiful; and the youngest was so beautiful that the sun itself, which has seen so much, "
    "was astonished whenever it shone in her face. Close by the king's castle lay a great dark "
    "forest, and under an old lime-tree in the forest was a well, and when the day was very "
    "warm, the king's child went out into the forest and sat down by the side of the cool "
    "fountain; and when she was bored she took a golden ball, and threw it up on high and "
    "caught it; and this ball was her favorite plaything.")
DECLARATION = (
    "When in the Course of human events, it becomes necessary for one people to dissolve the "
    "political bands which have connected them with another, and to assume among the powers of "
    "the earth, the separate and equal station to which the Laws of Nature and of Nature's God "
    "entitle them, a decent respect to the opinions of mankind requires that they should "
    "declare the causes which impel them to the separation.")
GETTYSBURG = (
    "Four score and seven years ago our fathers brought forth on this continent, a new nation, "
    "conceived in Liberty, and dedicated to the proposition that all men are created equal. Now "
    "we are engaged in a great civil war, testing whether that nation, or any nation so "
    "conceived and so dedicated, can long endure.")
MOBY = (
    "Call me Ishmael. Some years ago—never mind how long precisely—having little or "
    "no money in my purse, and nothing particular to interest me on shore, I thought I would "
    "sail about a little and see the watery part of the world. It is a way I have of driving "
    "off the spleen and regulating the circulation.")
DARWIN = (
    "When on board H.M.S. ‘Beagle,’ as naturalist, I was much struck with certain "
    "facts in the distribution of the inhabitants of South America, and in the geological "
    "relations of the present to the past inhabitants of that continent. These facts seemed to "
    "me to throw some light on the origin of species—that mystery of mysteries, as it has "
    "been called by one of our greatest philosophers.")
OWN = (
    "Typesetting mathematics requires an understanding of the interplay between characters, "
    "boxes, glue and penalties; the line-breaking algorithm considers every feasible breakpoint "
    "at once, choosing the sequence of lines that minimises the total demerits. "
    "Incomprehensibilities, uncharacteristically, institutionalisation and "
    "counterrevolutionaries test the hyphenation patterns thoroughly, while affine "
    "transformations of fluffy waffles in the office test the ligatures ff, fi, fl, ffi and ffl.")

TEXTS = [("frog", FROG), ("declaration", DECLARATION), ("gettysburg", GETTYSBURG),
         ("moby", MOBY), ("darwin", DARWIN), ("own", OWN)]
WIDTHS = [120, 160, 200, 250, 300, 345, 400]

HYPHENATION_WORDS = """
hyphenation concatenation programmable table office associate associates declination
obligatory philanthropic present presents project projects reciprocity recognizance
reformation retribution uncopyrightable supercalifragilisticexpialidocious
incomprehensibilities institutionalisation counterrevolutionaries characteristically
mathematics mathematician typesetting typography paragraph algorithm algorithms demerits
breakpoint breakpoints penalty penalties hyphen hyphens hyphenate hyphenated discretionary
Lagrangian Hamiltonian Euclidean Riemannian Noetherian Artinian polynomial polynomials
homomorphism isomorphism endomorphism automorphism topological topology manifold manifolds
differentiable integrable measurable continuous continuity convergence convergent
eigenvalue eigenvalues eigenvector orthogonal orthonormal commutative noncommutative
associativity distributivity transitivity reflexivity equivalence equivalences
formalization formalisation verification theorem theorems lemma lemmas corollary
proposition propositions definition definitions structure structures instance instances
academy network networks computer computers science scientific information
characters character boxes glue shrink stretch looseness tolerance emergency
Ishmael Liberty continent dedicated proposition beautiful astonished plaything
favorite fountain forest daughters youngest wishing philosophers inhabitants
distribution geological relations naturalist mysteries separation opinions
""".split()


def sample_words(path, step=150, limit=1600):
    """Every `step`-th word of the list with at least four letters, up to `limit` words."""
    words = []
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            w = line.strip()
            if i % step == 0 and len(w) >= 4 and w.isalpha():
                words.append(w)
                if len(words) >= limit:
                    break
    return words


def write(name, meta, cases):
    """One corpus file: the meta line, then one case per line, keys sorted."""
    os.makedirs("corpus/text", exist_ok=True)
    with open(f"corpus/text/{name}.jsonl", "w", encoding="utf-8") as f:
        f.write(json.dumps({"meta": dict(meta, corpus=name, count=len(cases))},
                           sort_keys=True, ensure_ascii=False) + "\n")
        for c in cases:
            f.write(json.dumps(c, sort_keys=True, ensure_ascii=False) + "\n")


def paragraphs():
    """The paragraph cases."""
    cases = []
    for key, text in TEXTS:
        for w in WIDTHS:
            cases.append({"id": f"par/{key}/{w}", "kind": "paragraph", "text": text, "hsize": w})
    for key, text in TEXTS[:3]:
        for font in ["italic", "bold", "sans", "mono", "slanted"]:
            cases.append({"id": f"par/{key}/font-{font}/250", "kind": "paragraph",
                          "text": text, "hsize": 250, "font": font})
        for size in [9, 12, 17]:
            cases.append({"id": f"par/{key}/size-{size}/300", "kind": "paragraph",
                          "text": text, "hsize": 300, "size": size})
    frog = FROG
    variants = [
        ("tolerance-100", {"tolerance": 100}),
        ("tolerance-1000", {"tolerance": 1000}),
        ("tolerance-10000", {"tolerance": 10000}),
        ("pretolerance-neg", {"pretolerance": -1}),
        ("pretolerance-10000", {"pretolerance": 10000}),
        ("looseness-plus1", {"looseness": 1}),
        ("looseness-minus1", {"looseness": -1}),
        ("emergency-20", {"tolerance": 100, "emergencystretch": 20}),
        ("ragged-right", {"rightskip": "0pt plus 30pt"}),
        ("ragged-left", {"leftskip": "0pt plus 1fil"}),
        ("centered", {"leftskip": "0pt plus 1fil", "rightskip": "0pt plus 1fil",
                      "parfillskip": "0pt"}),
        ("no-hyphens", {"hyphenpenalty": 10000, "exhyphenpenalty": 10000}),
        ("cheap-hyphens", {"hyphenpenalty": 0}),
        ("linepenalty-1000", {"linepenalty": 1000}),
        ("adjdemerits-0", {"adjdemerits": 0}),
        ("adjdemerits-100000", {"adjdemerits": 100000}),
        ("doublehyphen-0", {"doublehyphendemerits": 0, "hyphenpenalty": 0}),
        ("finalhyphen-0", {"finalhyphendemerits": 0}),
        ("parindent-15", {"parindent": 15}),
        ("parfillskip-0", {"parfillskip": "0pt"}),
        ("hang-after-2", {"hangindent": 30, "hangafter": 2}),
        ("hang-first-3", {"hangindent": 30, "hangafter": -3}),
        ("hang-right-2", {"hangindent": -30, "hangafter": -2}),
        ("parshape-3", {"parshape": [[0, 100], [20, 80], [40, 120]]}),
    ]
    for name, extra in variants:
        for w in [160, 250, 345]:
            cases.append(dict({"id": f"par/frog/{name}/{w}", "kind": "paragraph", "text": frog,
                               "hsize": w}, **extra))
    for w in [30, 60, 90]:
        cases.append({"id": f"par/own/overfull/{w}", "kind": "paragraph", "text": OWN,
                      "hsize": w})
    glue = [
        ("forced-break", ["First line ends here.", {"penalty": -10000}, "Second line."]),
        ("tie", ["Chapter", {"tie": True}, "7 and Section", {"tie": True},
                 "2 stay with their numbers in a narrow column of text."]),
        ("hfil", ["Left", {"glue": "0pt plus 1fil"}, "right"]),
        ("hfill-over-hfil", ["A", {"glue": "0pt plus 1fil"}, "B", {"glue": "0pt plus 1fill"},
                             "C"]),
        ("stretch-shrink", ["word", {"glue": "10pt plus 5pt minus 3pt"}, "word",
                            {"glue": "20pt plus 1pt minus 10pt"}, "word word word word word",
                            {"glue": "4pt plus 2pt minus 2pt"}, "word word word"]),
        ("kern", ["Kern", {"kern": 12.5}, "here", {"kern": -3}, "and here as well."]),
        ("penalty-50", ["Some text where a", {"penalty": 50}, "penalty of fifty is offered "
                        "and the breaker may or may not take it at this width."]),
        ("penalty-neg", ["A bonus", {"penalty": -500}, "for breaking here, in a paragraph long "
                         "enough to have a choice of breaks."]),
        ("nobreak", ["Never", {"penalty": 10000}, "break", {"penalty": 10000}, "between",
                     {"penalty": 10000}, "these words but anywhere else in the paragraph."]),
        ("hbox", ["An", {"hbox": "unbreakable box"}, "inside a paragraph, and",
                  {"hbox": "another one"}, "near its end."]),
        ("explicit-hyphens", ["Well-known, self-evident, state-of-the-art, "
                              "twenty-first-century compound words break at their hyphens."]),
    ]
    for name, parts in glue:
        for w in [80, 140, 220]:
            cases.append({"id": f"par/glue/{name}/{w}", "kind": "paragraph", "parts": parts,
                          "hsize": w})
    return cases


def boxes():
    """The single-line box cases."""
    samples = [
        ("ligatures", "ff fi fl ffi ffl office affine fluffy waffle"),
        ("kerning", "AVATAR To Ty Wa We Yo LT P. V. F, AV VA"),
        ("ascii-lower", "abcdefghijklmnopqrstuvwxyz"),
        ("ascii-upper", "ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
        ("digits", "0123456789 3.14159 1,000,000"),
        ("punctuation", "!?.,;:'\"()[]{}<>/\\|@#$%&*+=-_~^`"),
        ("quotes-dashes", "‘single’ “double” en–dash em—dash"),
        ("accents", "naïve café résumé über Straße ångström"),
        ("sentence", "The quick brown fox jumps over the lazy dog."),
    ]
    cases = []
    faces = ["regular", "italic", "bold", "bolditalic", "sans", "mono", "caps", "slanted"]
    for face in faces:
        for key, text in samples:
            cases.append({"id": f"box/{face}/{key}", "kind": "hbox", "text": text, "font": face})
    for size in [5, 7, 8, 9, 12, 17, 24]:
        cases.append({"id": f"box/regular/size-{size}", "kind": "hbox",
                      "text": "Office AVATAR fluffy waffle", "size": size})
    cases.append({"id": "box/regular/spaces", "kind": "hbox",
                  "text": "Spaces. After a period, a comma, and words."})
    return cases


def main():
    web2 = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/dict/web2"
    write("paragraphs", {"generator": "tools/text-corpus.py",
                         "license": "texts in the public domain (Grimm tr. Hunt 1884, the "
                                    "Declaration of Independence, the Gettysburg Address, "
                                    "Melville, Darwin) and Apache-2.0 (this repository)"},
          paragraphs())
    words = HYPHENATION_WORDS + [w for w in sample_words(web2) if w not in HYPHENATION_WORDS]
    write("words", {"generator": "tools/text-corpus.py",
                    "license": "Webster's Second International (1934; copyright lapsed) and "
                               "Apache-2.0 (this repository)"},
          [{"id": f"word/{i:04d}", "kind": "word", "word": w} for i, w in enumerate(words)])
    write("boxes", {"generator": "tools/text-corpus.py", "license": "Apache-2.0 (generated)"},
          boxes())


if __name__ == "__main__":
    main()
