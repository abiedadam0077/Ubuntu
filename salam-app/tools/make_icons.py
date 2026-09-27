#!/usr/bin/env python3
"""Generate the Salam app launcher icons (pure Python, no deps).

Renders a golden crescent moon + sparkle star on a deep indigo radial
gradient, with rounded corners, at all Android launcher densities.
"""
import math
import struct
import zlib
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "app", "src", "main", "res")

# ---------------------------------------------------------------- PNG writer
def write_png(path, w, h, rgba_rows):
    raw = b"".join(b"\x00" + bytes(row) for row in rgba_rows)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)

# ------------------------------------------------------------------- helpers
def lerp(a, b, t):
    return a + (b - a) * t

def clamp01(x):
    return 0.0 if x < 0.0 else (1.0 if x > 1.0 else x)

def sd_circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r

def sd_rounded_box(px, py, b, r):
    qx, qy = abs(px) - b, abs(py) - b
    ax, ay = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r

# colors
BG_IN  = (0x37, 0x30, 0xA3)   # indigo-800
BG_OUT = (0x0B, 0x10, 0x26)   # near-black navy
GOLD_A = (0xFB, 0xCF, 0x5A)   # light gold
GOLD_B = (0xE0, 0x93, 0x0C)   # deep gold
STAR_C = (0xFF, 0xF7, 0xD6)   # warm white

def render(size, ss=4):
    """Render one icon of `size` px (supersampled x ss), returns rows."""
    R = size * ss
    half = R / 2.0
    corner = R * 0.22
    rows = [[0] * (R * 4) for _ in range(R)]
    for y in range(R):
        py = (y - half) / R          # -0.5 .. 0.5, y down
        for x in range(R):
            px = (x - half) / R

            # ---- background radial gradient
            dr = math.hypot(px * 1.15, (py + 0.08) * 1.15)
            t = clamp01(dr / 0.58)
            r = lerp(BG_IN[0], BG_OUT[0], t)
            g = lerp(BG_IN[1], BG_OUT[1], t)
            b = lerp(BG_IN[2], BG_OUT[2], t)

            # soft gold rim-halo hugging the crescent edge
            glow = sd_circle(px, py, -0.045, -0.035, 0.315)
            gk = clamp01(1.0 - abs(glow) * 6.0) ** 2 * 0.30
            r = lerp(r, 0xFB, gk); g = lerp(g, 0xC8, gk); b = lerp(b, 0x5A, gk)

            # ---- crescent = big circle minus offset circle
            d_out = sd_circle(px, py, -0.045, -0.035, 0.30)
            d_cut = sd_circle(px, py, 0.115, -0.145, 0.265)
            d = max(d_out, -d_cut)
            a = clamp01(0.5 - d * R * 1.2)          # ~1px AA in unit space
            if a > 0:
                # vertical gold gradient on the crescent
                tg = clamp01((py + 0.32) / 0.62)
                cr = lerp(GOLD_A[0], GOLD_B[0], tg)
                cg = lerp(GOLD_A[1], GOLD_B[1], tg)
                cb = lerp(GOLD_A[2], GOLD_B[2], tg)
                r = lerp(r, cr, a); g = lerp(g, cg, a); b = lerp(b, cb, a)

            # ---- sparkle star (top-right opening of the crescent)
            sx, sy = px - 0.185, py + 0.145
            dv = (abs(sx) / 0.016 + abs(sy) / 0.085 - 1.0) / 1.01   # vertical spike
            dh = (abs(sy) / 0.016 + abs(sx) / 0.085 - 1.0) / 1.01   # horizontal spike
            ds = min(dv, dh)
            as_ = clamp01(0.5 - ds * R * 1.2)
            if as_ > 0:
                r = lerp(r, STAR_C[0], as_); g = lerp(g, STAR_C[1], as_); b = lerp(b, STAR_C[2], as_)

            # ---- rounded-corner mask
            dm = sd_rounded_box(px, py, 0.5 - corner / R, corner / R)
            am = clamp01(0.5 - dm * R * 1.2)
            alpha = int(255 * am)

            i = x * 4
            row = rows[y]
            row[i]     = int(r)
            row[i + 1] = int(g)
            row[i + 2] = int(b)
            row[i + 3] = alpha
    return rows, R

def downsample(rows, R, size):
    f = R // size
    out = []
    for y in range(size):
        row = [0] * (size * 4)
        for x in range(size):
            ar = ag = ab = aa = 0
            for dy in range(f):
                srow = rows[y * f + dy]
                for dx in range(f):
                    i = (x * f + dx) * 4
                    ar += srow[i]; ag += srow[i+1]; ab += srow[i+2]; aa += srow[i+3]
            n = f * f
            j = x * 4
            row[j]     = ar // n
            row[j + 1] = ag // n
            row[j + 2] = ab // n
            row[j + 3] = aa // n
        out.append(row)
    return out

def main():
    densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    master = None
    for name, size in densities.items():
        d = os.path.join(OUT, "mipmap-%s" % name)
        os.makedirs(d, exist_ok=True)
        rows, R = render(size)
        small = downsample(rows, R, size)
        write_png(os.path.join(d, "ic_launcher.png"), size, size, small)
        print("wrote mipmap-%s/ic_launcher.png (%dpx)" % (name, size))
        if size == 192:
            master = small
    # also a big one for the README / previews
    rows, R = render(512, ss=1)
    root = os.path.join(os.path.dirname(__file__), "..", "assets_src")
    os.makedirs(root, exist_ok=True)
    write_png(os.path.join(root, "icon_512.png"), 512, 512, rows)
    print("wrote assets_src/icon_512.png")

if __name__ == "__main__":
    main()
