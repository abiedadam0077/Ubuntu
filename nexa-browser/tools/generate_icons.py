#!/usr/bin/env python3
"""
Generates high-resolution Dark Premium Neon Blue/Purple launcher icons for NexaBrowser
using pure Python (struct + zlib) with anti-aliased procedural rendering.
"""
import math
import os
import struct
import zlib


def write_png(filepath, width, height, rgba_bytes):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    raw_rows = bytearray()
    stride = width * 4
    for y in range(height):
        raw_rows.append(0)  # Filter type 0 (None)
        raw_rows.extend(rgba_bytes[y * stride : (y + 1) * stride])

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw_rows), 9))
        + chunk(b"IEND", b"")
    )
    with open(filepath, "wb") as f:
        f.write(png)


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def lerp(a, b, t):
    return a + (b - a) * t


def dist_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay), 0.0
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = clamp(t, 0.0, 1.0)
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy), t


def render_icon(size, round_mask=False):
    buf = bytearray(size * size * 4)
    inv = 1.0 / size

    # Neon Nexa "N" + Orbit Ring geometry in normalized [-1, 1] coords
    # Left bar: (-0.34, 0.36) -> (-0.34, -0.36)
    # Diagonal: (-0.34, -0.36) -> (0.34, 0.36)
    # Right bar: (0.34, 0.36) -> (0.34, -0.36)
    segs = [
        (-0.33, 0.36, -0.33, -0.36, 0.0),
        (-0.33, -0.36, 0.33, 0.36, 0.5),
        (0.33, 0.36, 0.33, -0.36, 1.0),
    ]

    for py in range(size):
        ny = (py + 0.5) * inv * 2.0 - 1.0
        for px in range(size):
            nx = (px + 0.5) * inv * 2.0 - 1.0
            r_center = math.hypot(nx, ny)

            # Rounded squircle or circle mask
            if round_mask:
                edge_dist = r_center - 0.92
            else:
                # Superellipse squircle
                sx = abs(nx) / 0.90
                sy = abs(ny) / 0.90
                edge_dist = (sx ** 4.5 + sy ** 4.5) ** (1.0 / 4.5) - 1.0

            alpha = clamp(1.0 - edge_dist * (size * 0.45))
            if alpha <= 0.0:
                continue

            # Deep obsidian midnight background with radial blue/purple nebula
            bg_t = clamp((nx + ny + 1.4) * 0.35)
            r = lerp(6.0, 18.0, bg_t)
            g = lerp(9.0, 15.0, bg_t)
            b = lerp(22.0, 44.0, bg_t)

            # Ambient top-left cyan glow & bottom-right violet glow
            d_cyan = math.hypot(nx + 0.42, ny + 0.42)
            glow_cyan = math.exp(-d_cyan * d_cyan * 2.6)
            d_purp = math.hypot(nx - 0.42, ny - 0.42)
            glow_purp = math.exp(-d_purp * d_purp * 2.4)

            r += glow_cyan * 12.0 + glow_purp * 95.0
            g += glow_cyan * 115.0 + glow_purp * 28.0
            b += glow_cyan * 185.0 + glow_purp * 165.0

            # Outer glassmorphic neon ring
            ring_d = abs(r_center - 0.72)
            ring_glow = math.exp(-ring_d * ring_d * 180.0)
            ring_core = clamp(1.0 - (ring_d - 0.015) * (size * 0.35))
            ring_angle_t = 0.5 + 0.5 * math.sin(math.atan2(ny, nx) + 0.6)
            rr = lerp(0.0, 185.0, ring_angle_t)
            rg = lerp(225.0, 75.0, ring_angle_t)
            rb = lerp(255.0, 255.0, ring_angle_t)

            r += ring_glow * rr * 0.45
            g += ring_glow * rg * 0.45
            b += ring_glow * rb * 0.45

            if ring_core > 0:
                r = lerp(r, rr, ring_core * 0.85)
                g = lerp(g, rg, ring_core * 0.85)
                b = lerp(b, rb, ring_core * 0.85)

            # Distance to the "N" monogram
            min_d = 999.0
            color_t = 0.0
            for ax, ay, bx, by, base_t in segs:
                d, seg_t = dist_to_segment(nx, ny, ax, ay, bx, by)
                if d < min_d:
                    min_d = d
                    color_t = clamp((nx + 0.4) / 0.8)

            # Neon bloom around "N"
            n_bloom = math.exp(-min_d * min_d * 55.0)
            nr = lerp(0.0, 195.0, color_t)
            ng = lerp(235.0, 90.0, color_t)
            nb = 255.0

            r += n_bloom * nr * 0.65
            g += n_bloom * ng * 0.65
            b += n_bloom * nb * 0.65

            # Core stroke of "N"
            stroke_w = 0.095
            n_core = clamp(1.0 - (min_d - stroke_w) * (size * 0.38))
            if n_core > 0:
                # Bright white-cyan-violet hot center
                hot = clamp(1.0 - min_d / stroke_w)
                cr = lerp(nr, 248.0, hot * 0.65)
                cg = lerp(ng, 252.0, hot * 0.65)
                cb = lerp(nb, 255.0, hot * 0.65)
                r = lerp(r, cr, n_core)
                g = lerp(g, cg, n_core)
                b = lerp(b, cb, n_core)

            # Subtle inner border highlight
            border_d = abs(edge_dist + 0.02)
            if border_d < 0.03:
                bt = (1.0 - border_d / 0.03) * 0.35
                r = lerp(r, 110.0, bt)
                g = lerp(g, 195.0, bt)
                b = lerp(b, 255.0, bt)

            idx = (py * size + px) * 4
            buf[idx] = int(clamp(r, 0, 255))
            buf[idx + 1] = int(clamp(g, 0, 255))
            buf[idx + 2] = int(clamp(b, 0, 255))
            buf[idx + 3] = int(clamp(alpha * 255.0, 0, 255))

    return bytes(buf)


def main():
    base_res = "nexa-browser/app/src/main/res"
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in densities.items():
        sq = render_icon(sz, round_mask=False)
        rn = render_icon(sz, round_mask=True)
        write_png(os.path.join(base_res, folder, "ic_launcher.png"), sz, sz, sq)
        write_png(os.path.join(base_res, folder, "ic_launcher_round.png"), sz, sz, rn)
        print(f"Generated {folder} ({sz}x{sz})")

    # High-res icon for UI & showcase
    hi = render_icon(256, round_mask=False)
    write_png("nexa-browser/app/src/main/assets/ui/logo.png", 256, 256, hi)
    print("Generated assets/ui/logo.png (256x256)")


if __name__ == "__main__":
    main()
