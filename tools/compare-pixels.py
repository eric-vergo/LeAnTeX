# Released under Apache 2.0 license as described in the file LICENSE.
# Authors: Eric Vergo (Two-Circle Solutions), Claude (Anthropic)
#
# Compares two renderings of the same page pixel by pixel (tools/tex-render-compare.sh): two
# PNG files (8-bit grey, grey with alpha, RGB or RGBA, not interlaced, as macOS's Quick Look
# writes them), compared over the first's size. The second is mapped onto the first by the
# scale and offset that match their ink boxes (renderers round a page's size differently; the
# scale found is printed and should be within half a percent of 1) and sampled bilinearly, then
# aligned by the shift (within a few pixels) that minimises the difference. Pixels are compared
# as grey levels on white. Prints the mean difference in levels (of 255), the share of pixels
# within 32 and within 96 levels, the scale and the shift; exits 1 when the result is outside
# the given tolerance.
#
# Usage: python3 -I tools/compare-pixels.py A.png B.png [--max-mean M] [--min-within P]
#                                           [--diff OUT.pgm]
# Python's standard library only; the files are read as untrusted input (sizes are capped).
import struct
import sys
import zlib

MAX_SIDE = 20000


def read_png(path):
    """Decode a PNG into (width, height, grey rows on white)."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG")
    pos, idat, head = 8, [], None
    while pos + 8 <= len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            head = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
        pos += 12 + n
    if head is None:
        raise ValueError(f"{path}: no IHDR")
    w, h, depth, ctype, _, _, interlace = head
    if depth != 8 or interlace != 0 or ctype not in (0, 2, 4, 6) or w > MAX_SIDE or h > MAX_SIDE:
        raise ValueError(f"{path}: unsupported PNG ({depth} bits, type {ctype})")
    ch = {0: 1, 2: 3, 4: 2, 6: 4}[ctype]
    raw = zlib.decompressobj().decompress(b"".join(idat), (w * ch + 1) * h)
    rows, prev, stride = [], bytearray(w * ch), w * ch
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - ch] if i >= ch else 0
            b, c = prev[i], prev[i - ch] if i >= ch else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        grey = []
        for x in range(w):
            px = line[x * ch:(x + 1) * ch]
            v = px[0] if ch < 3 else (px[0] * 299 + px[1] * 587 + px[2] * 114) // 1000
            alpha = px[-1] if ch in (2, 4) else 255
            grey.append((v * alpha + 255 * (255 - alpha)) // 255)
        rows.append(grey)
    return w, h, rows


def ink_box(img):
    """The box (x0, y0, x1, y1) of the pixels darker than mid-grey."""
    w, h, r = img
    ys = [y for y in range(h) if min(r[y]) < 128]
    if not ys:
        return 0, 0, w - 1, h - 1
    xs = [x for x in range(w) if any(r[y][x] < 128 for y in ys)]
    return xs[0], ys[0], xs[-1], ys[-1]


def mapped(a, b):
    """B resampled onto A's grid by the scale and offset that match their ink boxes."""
    w, h, _ = a
    wb, hb, rb = b
    ax0, ay0, ax1, ay1 = ink_box(a)
    bx0, by0, bx1, by1 = ink_box(b)
    sx = (bx1 - bx0) / max(ax1 - ax0, 1)
    sy = (by1 - by0) / max(ay1 - ay0, 1)
    rows = []
    for y in range(h):
        fy = by0 + (y - ay0) * sy
        y0 = int(fy // 1)
        ty = fy - y0
        row = []
        for x in range(w):
            fx = bx0 + (x - ax0) * sx
            x0 = int(fx // 1)
            tx = fx - x0

            def at(xx, yy):
                return rb[yy][xx] if 0 <= yy < hb and 0 <= xx < wb else 255
            top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx
            bot = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx
            row.append(int(top * (1 - ty) + bot * ty + 0.5))
        rows.append(row)
    return (w, h, rows), sx, sy


def compare(a, b, dx, dy, step=1):
    """Mean difference and the shares within 32 and 96 levels, B shifted by (dx, dy), over
    every `step`th row and column."""
    w, h, ra = a
    wb, hb, rb = b
    total, n, near, mid = 0, 0, 0, 0
    for y in range(0, h, step):
        yb = y + dy
        for x in range(0, w, step):
            xb = x + dx
            vb = rb[yb][xb] if 0 <= yb < hb and 0 <= xb < wb else 255
            d = abs(ra[y][x] - vb)
            total += d
            n += 1
            near += d <= 32
            mid += d <= 96
    return total / max(n, 1), near / max(n, 1), mid / max(n, 1)


def main(argv):
    args = argv[1:]
    opts = {"--max-mean": None, "--min-within": None, "--diff": None}
    files = []
    while args:
        k = args.pop(0)
        if k in opts and args:
            opts[k] = args.pop(0)
        else:
            files.append(k)
    if len(files) != 2:
        print("usage: compare-pixels.py A.png B.png [--max-mean M] [--min-within P] "
              "[--diff OUT.pgm]", file=sys.stderr)
        return 2
    a, b = read_png(files[0]), read_png(files[1])
    for name, img in zip(files, (a, b)):
        if not any(v < 128 for row in img[2] for v in row):
            print(f"{name}: no ink", file=sys.stderr)
            return 1
    b, sx, sy = mapped(a, b)
    best = None
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            m = compare(a, b, dx, dy, 3)
            if best is None or m[0] < best[0][0]:
                best = (m, dx, dy)
    _, dx, dy = best
    mean, near, mid = compare(a, b, dx, dy)
    print(f"mean {mean:.3f} levels; within 32 levels {100 * near:.3f} %; "
          f"within 96 levels {100 * mid:.3f} %; scale {sx:.4f} x {sy:.4f}; shift ({dx}, {dy}) px")
    if opts["--diff"]:
        w, h, ra = a
        _, _, rb = b
        with open(opts["--diff"], "wb") as out:
            out.write(f"P5 {w} {h} 255\n".encode())
            for y in range(h):
                out.write(bytes(255 - min(255, abs(ra[y][x] - (rb[y + dy][x + dx]
                    if 0 <= y + dy < len(rb) and 0 <= x + dx < len(rb[0]) else 255)))
                    for x in range(w)))
    ok = True
    if opts["--max-mean"] is not None and mean > float(opts["--max-mean"]):
        ok = False
    if opts["--min-within"] is not None and 100 * near < float(opts["--min-within"]):
        ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
