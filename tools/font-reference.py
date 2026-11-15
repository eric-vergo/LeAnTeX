# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Records what fontTools reads from the Latin Modern OpenType fonts into fixtures/font/<font>.jsonl,
# the reference for LeAnTeX's font reader (LeAnTeXTest/Font.lean): the header metrics, names,
# OS/2 and post fields, the MATH constants, the character map, and per glyph its advance, left
# side bearing, control-point box, tight box and a hash of its outline. The fonts are those the
# text fixtures use (fixtures/text/boxes.jsonl) and Latin Modern Math; they are not committed,
# and the test compares a font only when it finds the same file (by SHA-256).
#
# Usage, from the repository root:  python3 -I tools/font-reference.py [FONT_DIR …]
# FONT_DIR defaults to TeX Live's OpenType directories found through kpsewhich. Needs fontTools.
#
# The outline hash: FNV-1a (64 bit) of the outline as text, `M x y`, `L x y`, `Q cx cy x y`,
# `C c1x c1y c2x c2y x y`, `Z` joined by single spaces, every coordinate an integer in 1/65536
# font units; LeAnTeX's test computes the same text from its own outline.

import hashlib
import json
import os
import subprocess
import sys

from fontTools.pens.boundsPen import BoundsPen, ControlBoundsPen
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.ttLib import TTFont
import fontTools

MATH_NAMES = [
    "ScriptPercentScaleDown", "ScriptScriptPercentScaleDown", "DelimitedSubFormulaMinHeight",
    "DisplayOperatorMinHeight", "MathLeading", "AxisHeight", "AccentBaseHeight",
    "FlattenedAccentBaseHeight", "SubscriptShiftDown", "SubscriptTopMax",
    "SubscriptBaselineDropMin", "SuperscriptShiftUp", "SuperscriptShiftUpCramped",
    "SuperscriptBottomMin", "SuperscriptBaselineDropMax", "SubSuperscriptGapMin",
    "SuperscriptBottomMaxWithSubscript", "SpaceAfterScript", "UpperLimitGapMin",
    "UpperLimitBaselineRiseMin", "LowerLimitGapMin", "LowerLimitBaselineDropMin",
    "StackTopShiftUp", "StackTopDisplayStyleShiftUp", "StackBottomShiftDown",
    "StackBottomDisplayStyleShiftDown", "StackGapMin", "StackDisplayStyleGapMin",
    "StretchStackTopShiftUp", "StretchStackBottomShiftDown", "StretchStackGapAboveMin",
    "StretchStackGapBelowMin", "FractionNumeratorShiftUp", "FractionNumeratorDisplayStyleShiftUp",
    "FractionDenominatorShiftDown", "FractionDenominatorDisplayStyleShiftDown",
    "FractionNumeratorGapMin", "FractionNumDisplayStyleGapMin", "FractionRuleThickness",
    "FractionDenominatorGapMin", "FractionDenomDisplayStyleGapMin",
    "SkewedFractionHorizontalGap", "SkewedFractionVerticalGap", "OverbarVerticalGap",
    "OverbarRuleThickness", "OverbarExtraAscender", "UnderbarVerticalGap",
    "UnderbarRuleThickness", "UnderbarExtraDescender", "RadicalVerticalGap",
    "RadicalDisplayStyleVerticalGap", "RadicalRuleThickness", "RadicalExtraAscender",
    "RadicalKernBeforeDegree", "RadicalKernAfterDegree", "RadicalDegreeBottomRaisePercent"]


def fnv1a(text):
    """FNV-1a, 64 bit, of the UTF-8 bytes of `text`."""
    h = 0xcbf29ce484222325
    for b in text.encode("utf-8"):
        h ^= b
        h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h


def fx(v):
    """A coordinate in font units as an integer in 1/65536."""
    return int(round(v * 65536))


def outline_text(ops):
    """The canonical outline text of a recording pen's operations."""
    out, cur = [], None
    for op, args in ops:
        if op == "moveTo":
            cur = args[0]
            out.append("M%d %d" % (fx(cur[0]), fx(cur[1])))
        elif op == "lineTo":
            cur = args[0]
            out.append("L%d %d" % (fx(cur[0]), fx(cur[1])))
        elif op == "curveTo":
            pts = " ".join("%d %d" % (fx(x), fx(y)) for x, y in args)
            out.append("C" + pts)
        elif op == "qCurveTo":
            out.append("Q" + " ".join("%d %d" % (fx(x), fx(y)) for x, y in args))
        elif op in ("closePath", "endPath"):
            out.append("Z")
    return " ".join(out)


def font_dirs():
    """TeX Live's directories of the Latin Modern OpenType fonts."""
    dirs = []
    for name in ["lmroman10-regular.otf", "latinmodern-math.otf"]:
        try:
            p = subprocess.run(["kpsewhich", name], capture_output=True, text=True,
                               check=False).stdout.strip()
        except OSError:
            p = ""
        if p:
            dirs.append(os.path.dirname(p))
    return dirs


def wanted_fonts():
    """The font files the box fixtures name, and Latin Modern Math."""
    names = {"latinmodern-math.otf"}
    with open("fixtures/text/boxes.jsonl", encoding="utf-8") as f:
        for line in f:
            d = json.loads(line)
            for font in d.get("fonts", []):
                names.add(font["file"])
    return sorted(names)


def record(path, out):
    """Writes the reference of one font."""
    data = open(path, "rb").read()
    t = TTFont(path)
    gs = t.getGlyphSet()
    order = t.getGlyphOrder()
    head, hhea = t["head"], t["hhea"]
    os2, post = t["OS/2"], t["post"]
    names = {str(i): t["name"].getDebugName(i) for i in [1, 2, 4, 6]
             if t["name"].getDebugName(i) is not None}
    info = {
        "unitsPerEm": head.unitsPerEm, "numGlyphs": len(order),
        "head": [head.xMin, head.yMin, head.xMax, head.yMax, head.macStyle],
        "hhea": [hhea.ascent, hhea.descent, hhea.lineGap, hhea.numberOfHMetrics],
        "os2": [os2.version, os2.xAvgCharWidth, os2.usWeightClass, os2.usWidthClass,
                os2.fsType, os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap,
                os2.usWinAscent, os2.usWinDescent,
                getattr(os2, "sxHeight", None), getattr(os2, "sCapHeight", None)],
        "post": [int(round(post.italicAngle * 65536)), post.underlinePosition,
                 post.underlineThickness, bool(post.isFixedPitch)],
        "names": names,
    }
    if "MATH" in t:
        mc = t["MATH"].table.MathConstants
        info["math"] = [getattr(getattr(mc, n), "Value", getattr(mc, n)) for n in MATH_NAMES]
    cmap = t.getBestCmap()
    gid = {n: i for i, n in enumerate(order)}
    with open(out, "w", encoding="utf-8") as f:
        f.write(json.dumps({"meta": {
            "font": os.path.basename(path), "sha256": hashlib.sha256(data).hexdigest(),
            "fontTools": fontTools.version, "recorder": "tools/font-reference.py"}},
            sort_keys=True) + "\n")
        f.write(json.dumps({"info": info}, sort_keys=True) + "\n")
        f.write(json.dumps({"cmap": sorted([c, gid[n]] for c, n in cmap.items())}) + "\n")
        for i, n in enumerate(order):
            adv, lsb = t["hmtx"][n]
            cb, bb = ControlBoundsPen(gs), BoundsPen(gs)
            gs[n].draw(cb)
            gs[n].draw(bb)
            rec = DecomposingRecordingPen(gs)
            gs[n].draw(rec)
            text = outline_text(rec.value)
            box = lambda b: None if b is None else [fx(v) for v in b]
            f.write(json.dumps({"g": [i, adv, lsb, box(cb.bounds), box(bb.bounds),
                                      "%016x" % fnv1a(text)]}) + "\n")


def main():
    dirs = sys.argv[1:] or font_dirs()
    os.makedirs("fixtures/font", exist_ok=True)
    for name in wanted_fonts():
        path = next((os.path.join(d, name) for d in dirs
                     if os.path.exists(os.path.join(d, name))), None)
        if path is None:
            print("font-reference: not found:", name)
            continue
        stem = os.path.splitext(name)[0]
        record(path, f"fixtures/font/{stem}.jsonl")
        print("font-reference:", name)


if __name__ == "__main__":
    main()
