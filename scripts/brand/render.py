"""Render Opscode pixel mascots + logo to SVG/PNG.

Usage: python3 scripts/brand/render.py   (writes assets/brand/)
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from sprites import COMMON, PEOPLE, ANIMALS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "brand")
CANVAS = 20  # sprite canvas incl. outline
OUTLINE = COMMON["k"]


def hex_rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def shade(hexc, f):
    r, g, b, _ = hex_rgba(hexc)
    if f > 1:
        r, g, b = (int(v + (255 - v) * (f - 1)) for v in (r, g, b))
    else:
        r, g, b = (int(v * f) for v in (r, g, b))
    return f"#{r:02X}{g:02X}{b:02X}"


def build_grid(pal, rows):
    """Return CANVAS x CANVAS grid of hex colours (or None), outlined, bottom-centred."""
    pal = {**COMMON, **pal}
    w = max(len(r) for r in rows)
    rows = [r.ljust(w, ".") for r in rows]
    # trim empty columns to centre on real content
    cols = [x for x in range(w) if any(r[x] != "." for r in rows)]
    x0, x1 = min(cols), max(cols)
    rows = [r[x0:x1 + 1] for r in rows]
    w, h = x1 - x0 + 1, len(rows)
    assert w + 2 <= CANVAS and h + 2 <= CANVAS, (w, h)
    ox = (CANVAS - w) // 2
    oy = CANVAS - 1 - h  # 1px outline at bottom
    grid = [[None] * CANVAS for _ in range(CANVAS)]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                if ch not in pal:
                    raise KeyError(f"unknown palette key {ch!r}")
                grid[oy + y][ox + x] = pal[ch]
    # rim shading: darker bottom/right edges, lighter top/left edges
    skip = {COMMON["e"], COMMON["w"], COMMON["p"], OUTLINE, pal.get("e"), pal.get("n")}
    shaded = [row[:] for row in grid]

    def empty(x, y):
        return not (0 <= x < CANVAS and 0 <= y < CANVAS) or grid[y][x] is None

    for y in range(CANVAS):
        for x in range(CANVAS):
            c = grid[y][x]
            if c is None or c in skip:
                continue
            if empty(x + 1, y) or empty(x, y + 1):
                shaded[y][x] = shade(c, 0.80)
            elif empty(x - 1, y) or empty(x, y - 1):
                shaded[y][x] = shade(c, 1.12)
    grid = shaded
    out = [row[:] for row in grid]
    for y in range(CANVAS):
        for x in range(CANVAS):
            if grid[y][x] is None:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < CANVAS and 0 <= ny < CANVAS and grid[ny][nx] is not None:
                        out[y][x] = OUTLINE
                        break
    return out


def grid_svg(grid, size=None):
    n = len(grid)
    parts = []
    for y, row in enumerate(grid):
        x = 0
        while x < n:
            c = row[x]
            if c is None:
                x += 1
                continue
            run = 1
            while x + run < n and row[x + run] == c:
                run += 1
            parts.append(f'<rect x="{x}" y="{y}" width="{run}" height="1" fill="{c}"/>')
            x += run
    sz = f' width="{size}" height="{size}"' if size else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n} {n}"{sz} '
            f'shape-rendering="crispEdges">' + "".join(parts) + "</svg>\n")


def grid_png(grid, scale):
    n = len(grid)
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c:
                px[x, y] = hex_rgba(c)
    return img.resize((n * scale, n * scale), Image.NEAREST)


# ---------------------------------------------------------------- logo
FONT = {  # 5 wide, 9 tall (2 ascender, 5 x-height, 2 descender)
    "o": ["", "", ".###.", "#...#", "#...#", "#...#", ".###.", "", ""],
    "p": ["", "", "####.", "#...#", "#...#", "#...#", "####.", "#....", "#...."],
    "s": ["", "", ".####", "#....", ".###.", "....#", "####.", "", ""],
    "c": ["", "", ".####", "#....", "#....", "#....", ".####", "", ""],
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####", "", ""],
    "e": ["", "", ".###.", "#...#", "#####", "#....", ".####", "", ""],
}

# 16x16 mark: chevron prompt + cursor, cream on orange tile
MARK = [
    "................",
    "................",
    "................",
    "...##...........",
    "...###..........",
    "....###.........",
    ".....###........",
    "......###.......",
    "......###.......",
    ".....###........",
    "....###.........",
    "...###...######.",
    "...##....######.",
    "................",
    "................",
    "................",
]

ORANGE_TOP = "#FFB15C"
ORANGE_MID = "#FF7A2F"
ORANGE_BOT = "#E04E14"
CREAM = "#FFF4E6"
INK = "#3A1606"


def mark_svg(size=512, radius_ratio=0.225, rounded=True):
    """App-icon style: gradient squircle + pixel chevron with drop shadow."""
    cell = 1  # viewBox units: 16 + 4 padding = 24 grid? use 24 grid for padding
    G = 24
    off = 4
    r = G * radius_ratio if rounded else 0
    rects_shadow, rects_fg = [], []
    for y, row in enumerate(MARK):
        x = 0
        while x < 16:
            if row[x] != "#":
                x += 1
                continue
            run = 1
            while x + run < 16 and row[x + run] == "#":
                run += 1
            rects_fg.append(f'<rect x="{x+off}" y="{y+off}" width="{run}" height="1"/>')
            rects_shadow.append(f'<rect x="{x+off+0.0}" y="{y+off+0.5}" width="{run}" height="1"/>')
            x += run
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {G} {G}" width="{size}" height="{size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="{ORANGE_TOP}"/>
      <stop offset="0.5" stop-color="{ORANGE_MID}"/>
      <stop offset="1" stop-color="{ORANGE_BOT}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.3" cy="0.15" r="0.75">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="fg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="{CREAM}"/>
    </linearGradient>
  </defs>
  <rect width="{G}" height="{G}" rx="{r}" fill="url(#bg)"/>
  <rect width="{G}" height="{G}" rx="{r}" fill="url(#glow)"/>
  <rect x="0.25" y="0.25" width="{G-0.5}" height="{G-0.5}" rx="{max(r-0.25,0)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="0.5"/>
  <g fill="{INK}" fill-opacity="0.18" shape-rendering="crispEdges">{''.join(rects_shadow)}</g>
  <g fill="url(#fg)" shape-rendering="crispEdges">{''.join(rects_fg)}</g>
</svg>
'''


def word_rects(text, color, x0=0, y0=0, gap=1):
    rects, x = [], x0
    for ch in text:
        glyph = FONT[ch]
        for gy, row in enumerate(glyph):
            for gx, c in enumerate(row):
                if c == "#":
                    rects.append(f'<rect x="{x+gx}" y="{y0+gy}" width="1" height="1"/>')
        x += 5 + gap
    return "".join(rects), x - gap - x0


def lockup_svg(text_color, height=96):
    # mark occupies 24 units, word 9 units tall scaled x2 => 18
    mark = mark_svg(size=24).split("\n", 1)[1].rsplit("</svg>", 1)[0]
    ops, w1 = word_rects("ops", ORANGE_MID)
    code, w2 = word_rects("code", text_color, x0=w1 + 1)
    ww = w1 + 1 + w2
    scale = 2
    W = 24 + 6 + ww * scale + 2
    H = 24
    ty = (H - 7 * scale) / 2 - 2 * scale + 1  # centre the x-height+ascender on the mark
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" height="{height}" width="{height*W/H:.0f}">
  <svg x="0" y="0" width="24" height="24" viewBox="0 0 24 24">{mark}</svg>
  <g transform="translate(30 {ty}) scale({scale})" shape-rendering="crispEdges">
    <g fill="{ORANGE_MID}">{ops}</g><g fill="{text_color}">{code}</g>
  </g>
</svg>
'''


def svg_to_png(svg_path, png_path, size):
    os.system(f'rsvg-convert -w {size} -h {size} "{svg_path}" -o "{png_path}"')


def main():
    os.makedirs(os.path.join(OUT, "mascots", "svg"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "mascots", "png"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "logo"), exist_ok=True)

    groups = [("People", PEOPLE), ("Animals", ANIMALS)]
    manifest = []
    sheet_items = []
    for gname, items in groups:
        for key, label, pal, rows in items:
            grid = build_grid(pal, rows)
            with open(os.path.join(OUT, "mascots", "svg", f"{key}.svg"), "w") as f:
                f.write(grid_svg(grid))
            for scale in (4, 8, 16):
                grid_png(grid, scale).save(
                    os.path.join(OUT, "mascots", "png", f"{key}@{scale}x.png"))
            manifest.append({"id": key, "label": label, "group": gname})
            sheet_items.append((gname, key, label, grid))

    # contact sheet (dark, like an avatar picker)
    scale, pad, cols = 6, 18, 8
    cell = CANVAS * scale + pad
    n = len(sheet_items)
    rows_n = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell + pad, rows_n * cell + pad), (26, 26, 28, 255))
    for i, (_, key, _, grid) in enumerate(sheet_items):
        x = pad + (i % cols) * cell
        y = pad + (i // cols) * cell
        ImageDraw.Draw(sheet).rounded_rectangle(
            [x - 6, y - 6, x + CANVAS * scale + 6, y + CANVAS * scale + 6], 12,
            fill=(34, 34, 37, 255))
        spr = grid_png(grid, scale)
        sheet.alpha_composite(spr, (x, y))
    sheet.save(os.path.join(OUT, "mascots", "contact-sheet.png"))

    import json
    with open(os.path.join(OUT, "mascots", "mascots.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    # logo
    L = os.path.join(OUT, "logo")
    with open(os.path.join(L, "opscode-mark.svg"), "w") as f:
        f.write(mark_svg())
    with open(os.path.join(L, "opscode-lockup-dark.svg"), "w") as f:
        f.write(lockup_svg("#F5F2EE"))
    with open(os.path.join(L, "opscode-lockup-light.svg"), "w") as f:
        f.write(lockup_svg("#1C1A19"))
    for s in (16, 32, 64, 128, 256, 512, 1024):
        svg_to_png(os.path.join(L, "opscode-mark.svg"), os.path.join(L, f"opscode-mark-{s}.png"), s)
    print(f"wrote {len(manifest)} mascots + logo to {OUT}")


if __name__ == "__main__":
    main()
