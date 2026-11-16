# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Builds the two small fonts the font reader's tests use without TeX installed:
#   fixtures/font/leantex-test-cff.otf   CFF outlines written as hand-made Type 2 programs that use
#                                        every path operator, local and global subroutines, hint
#                                        masks and flex; GSUB `liga` and GPOS `kern` (a pair and a
#                                        class subtable);
#   fixtures/font/leantex-test-glyf.ttf  TrueType outlines with implied on-curve points and a
#                                        scaled composite glyph; a version-0 `kern` table.
# Their shapes are drawn here (no third-party outlines), so the files are this repository's own,
# under its licence. tools/font-reference.py --test-fonts then records what fontTools reads.
# The fonts' creation and modification times are fixed (STAMP), so the script writes the same
# bytes on every run.
#
# Usage, from the repository root: python3 -I tools/test-fonts.py

from fontTools.cffLib import PrivateDict
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.fontBuilder import FontBuilder
from fontTools.misc.psCharStrings import T2CharString
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0
from fontTools.cffLib import SubrsIndex, GlobalSubrsIndex

# The `head` table's `created` and `modified`: seconds since 1904, the moment the committed
# fonts were first built.
STAMP = 3877551039


def save(fb, path):
    """Writes the font with its times set to STAMP and not recalculated."""
    fb.font["head"].created = STAMP
    fb.font["head"].modified = STAMP
    fb.font.recalcTimestamp = False
    fb.save(path)


ORDER = [".notdef", "space", "A", "f", "i", "f_i", "acute", "Aacute"]
CMAP = {0x20: "space", 0x41: "A", 0x66: "f", 0x69: "i", 0xFB01: "f_i", 0xB4: "acute",
        0xC1: "Aacute"}
ADVANCES = {".notdef": 500, "space": 250, "A": 600, "f": 300, "i": 250, "f_i": 550,
            "acute": 300, "Aacute": 600}
FEATURES = """
languagesystem DFLT dflt;
languagesystem latn dflt;
feature liga { sub f i by f_i; } liga;
feature kern {
  pos A A -50;
  pos A f -30;
  pos [A f] [i Aacute] -10;
} kern;
"""


def cff_font():
    """The CFF test font."""
    fb = FontBuilder(1000, isTTF=False)
    fb.setupGlyphOrder(ORDER)
    fb.setupCharacterMap(CMAP)
    # Subroutine indices are biased by 107 (fewer than 1240 subroutines).
    progs = {
        ".notdef": [500, 50, 0, "rmoveto", 400, 0, 0, 700, -400, 0, "rlineto", "endchar"],
        "space": [250, "endchar"],
        # stems, a hint mask, a line pair from a local subroutine
        "A": [600, 0, 50, "hstemhm", 20, 40, "vstemhm", "hintmask", bytes([0xC0]),
              0, 0, "rmoveto", 0 - 107, "callsubr", -600, "hlineto", "endchar"],
        # curves of every alternating form, a global subroutine
        "f": [300, 80, "hmoveto", 60, 500, "vlineto", 40, 100, 80, 40, "vhcurveto",
              30, 0, 30, -20, "hvcurveto", 0 - 107, "callgsubr", "endchar"],
        # two contours, vmoveto and hmoveto
        "i": [250, 60, "hmoveto", 100, 450, -100, "hlineto", 100, 580, "rmoveto",
              60, 60, 0, 60, -60, -60, "rrcurveto", "endchar"],
        # hh/vv curves, rcurveline, rlinecurve, flex
        "f_i": [550, 50, 0, "rmoveto", 10, 100, 20, 80, 30, "hhcurveto", 10, 90, 30, 40, 50,
                "vvcurveto", 20, 30, 40, 50, 60, 70, 10, 10, "rcurveline",
                10, 0, 0, 10, 20, 20, 30, 30, 40, 40, "rlinecurve",
                20, 20, 20, 0, 20, -20, 20, -20, 20, 0, 20, 20, 50, "flex",
                -300, "hlineto", "endchar"],
        "acute": [300, 100, 600, "rmoveto", 100, 100, -50, 0, "rlineto", "endchar"],
        "Aacute": [600, 0, 0, "rmoveto", 0 - 107, "callsubr", -600, "hlineto",
                   250, 750, "rmoveto", 100, 100, -50, 0, "rlineto", "endchar"],
    }
    charstrings = {n: T2CharString(program=p) for n, p in progs.items()}
    fb.setupCFF("LeAnTeXTestCFF", {"FullName": "LeAnTeX Test CFF"}, charstrings, {})
    fb.setupHorizontalMetrics({n: (ADVANCES[n], 0) for n in ORDER})
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({"familyName": "LeAnTeX Test CFF", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200,
                sxHeight=450, sCapHeight=700)
    fb.setupPost()
    cff = fb.font["CFF "].cff
    top = cff.topDictIndex[0]
    subrs = SubrsIndex()
    subrs.append(T2CharString(program=[300, 700, 300, -700, "return"]))
    top.Private.Subrs = subrs
    gsubrs = cff.GlobalSubrs
    gsubrs.append(T2CharString(program=[-50, -100, -30, "vlineto", "return"]))
    for cs in top.CharStrings.values():
        cs.private = top.Private
        cs.globalSubrs = gsubrs
    addOpenTypeFeaturesFromString(fb.font, FEATURES)
    fb.font.recalcBBoxes = True
    save(fb, "fixtures/font/leantex-test-cff.otf")


def glyf_font():
    """The TrueType test font."""
    fb = FontBuilder(1024, isTTF=True)
    fb.setupGlyphOrder(ORDER)
    fb.setupCharacterMap(CMAP)
    glyphs = {}

    def draw(name, contours):
        pen = TTGlyphPen(None)
        for c in contours:
            kind, pts = c
            pen.moveTo(pts[0])
            if kind == "line":
                for p in pts[1:]:
                    pen.lineTo(p)
            else:
                # one quadratic spline through several off-curve points (implied on-curve points)
                pen.qCurveTo(*pts[1:])
            pen.closePath()
        glyphs[name] = pen.glyph()

    draw(".notdef", [("line", [(50, 0), (450, 0), (450, 700), (50, 700)])])
    draw("space", [])
    draw("A", [("line", [(0, 0), (300, 700), (600, 0)])])
    draw("f", [("quad", [(80, 0), (80, 500), (150, 650), (300, 600), (200, 400), (140, 0)])])
    draw("i", [("line", [(60, 0), (160, 0), (160, 450), (60, 450)]),
               ("quad", [(110, 520), (170, 560), (110, 620), (50, 560), (110, 520)])])
    draw("f_i", [("quad", [(50, 0), (50, 600), (300, 700), (500, 600), (500, 0)])])
    draw("acute", [("line", [(100, 600), (200, 700), (150, 700)])])
    pen = TTGlyphPen(glyphs)
    pen.addComponent("A", (1, 0, 0, 1, 0, 0))
    pen.addComponent("acute", (0.75, 0, 0, 0.5, 200, 300))
    glyphs["Aacute"] = pen.glyph()
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    for n in ORDER:
        glyf[n].recalcBounds(glyf)
    fb.setupHorizontalMetrics({n: (ADVANCES[n], getattr(glyf[n], "xMin", 0)) for n in ORDER})
    fb.setupHorizontalHeader(ascent=820, descent=-204)
    fb.setupNameTable({"familyName": "LeAnTeX Test glyf", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=820, sTypoDescender=-204, usWinAscent=820, usWinDescent=204)
    fb.setupPost()
    kern = newTable("kern")
    kern.version = 0
    sub = KernTable_format_0()
    sub.version, sub.coverage, sub.format = 0, 1, 0
    sub.kernTable = {("A", "A"): -40, ("A", "f"): -20, ("f", "i"): 15}
    kern.kernTables = [sub]
    fb.font["kern"] = kern
    save(fb, "fixtures/font/leantex-test-glyf.ttf")


if __name__ == "__main__":
    cff_font()
    glyf_font()
