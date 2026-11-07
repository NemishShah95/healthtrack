"""Draws the HealthTrack app icon (1024 x 1024, full bleed: iOS rounds the corners itself).

    python3 Design/make-icon.py <orbit|pulse|night> <out.png>

Design by Nemish Shah, not covered by the MIT licence (see TRADEMARKS.md).
Colours match HealthTrack/Shared/Theme.swift. Drawn 4x larger, then scaled down for smooth edges.
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4096  # working size
NAVY_TOP, NAVY_BOTTOM = (0x12, 0x30, 0x3D), (0x05, 0x0C, 0x11)
TEAL_GLOW, LIME_GLOW = (0x1D, 0x5E, 0x5C), (0x3F, 0x62, 0x20)
LIME, LIME_DEEP, TEAL = (0xC8, 0xF2, 0x5C), (0x86, 0xD6, 0x5A), (0x4F, 0xC9, 0xBD)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        d.line([(0, y), (S, y)], fill=mix(NAVY_TOP, NAVY_BOTTOM, y / S))
    for colour, (cx, cy), radius, strength in [(TEAL_GLOW, (0.78, 0.18), 0.6, 0.6), (LIME_GLOW, (0.18, 0.9), 0.42, 0.22)]:
        glow = Image.new("RGB", (S, S), colour)
        mask = Image.new("L", (S, S), 0)
        r = radius * S
        ImageDraw.Draw(mask).ellipse([cx * S - r, cy * S - r, cx * S + r, cy * S + r], fill=round(255 * strength))
        img = Image.composite(glow, img, mask.filter(ImageFilter.GaussianBlur(S * 0.12)))
    return img


def point(center, radius, degrees):
    a = math.radians(degrees)
    return center[0] + radius * math.cos(a), center[1] + radius * math.sin(a)


def gradient_arc(draw, center, radius, width, start, sweep, c0, c1):
    """Round-capped arc, colour moving from c0 to c1 along it (angles: 0 = right, clockwise)."""
    steps = max(2, int(abs(sweep) * 4))
    for i in range(steps + 1):
        t = i / steps
        x, y = point(center, radius, start + sweep * t)
        r = width / 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=mix(c0, c1, t))


def glow_dot(img, xy, radius, colour, halo):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = xy
    d.ellipse([x - halo, y - halo, x + halo, y + halo], fill=colour + (150,))
    layer = layer.filter(ImageFilter.GaussianBlur(halo * 0.55))
    d = ImageDraw.Draw(layer)
    d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=colour + (255,))
    img.alpha_composite(layer)


def ring_track(img, center, radius, width):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r1, r2 = radius + width / 2, radius - width / 2
    d = ImageDraw.Draw(layer)
    d.ellipse([center[0] - r1, center[1] - r1, center[0] + r1, center[1] + r1], fill=(255, 255, 255, 30))
    d.ellipse([center[0] - r2, center[1] - r2, center[0] + r2, center[1] + r2], fill=(0, 0, 0, 0))
    img.alpha_composite(layer)


def draw(option):
    img = background().convert("RGBA")
    c, R, W = (S / 2, S / 2), S * 0.29, S * 0.085
    ring_track(img, c, R, W)
    d = ImageDraw.Draw(img)
    if option == "orbit":
        # The consistency ring, three-quarters done, with the Steps card's glowing orbit dot at its tip.
        sweep = 285
        gradient_arc(d, c, R, W, -90, sweep, LIME_DEEP, LIME)
        glow_dot(img, point(c, R, -90 + sweep), W * 0.36, (0xF4, 0xFF, 0xD6), W * 1.1)
    elif option == "pulse":
        # Ring plus a heartbeat line through the middle.
        gradient_arc(d, c, R, W, -90, 300, LIME_DEEP, LIME)
        pts = [(-0.62, 0), (-0.22, 0), (-0.1, -0.32), (0.06, 0.36), (0.18, -0.12), (0.26, 0), (0.62, 0)]
        line = [(c[0] + x * R, c[1] + y * R) for x, y in pts]
        d.line(line, fill=(0xF1, 0xF5, 0xF4), width=round(W * 0.42), joint="curve")
        for x, y in (line[0], line[-1]):
            r = W * 0.21
            d.ellipse([x - r, y - r, x + r, y + r], fill=(0xF1, 0xF5, 0xF4))
    elif option == "night":
        # Day and night: lime ring for the habits, a teal crescent inside for sleep.
        gradient_arc(d, c, R, W, -90, 285, LIME_DEEP, LIME)
        m = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(m)
        r = R * 0.5
        md.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=255)
        ox, oy = r * 0.45, -r * 0.3
        md.ellipse([c[0] - r + ox, c[1] - r + oy, c[0] + r + ox, c[1] + r + oy], fill=0)
        img.paste(Image.new("RGBA", (S, S), TEAL + (255,)), (0, 0), m)
        glow_dot(img, point(c, R, -90 + 285), W * 0.3, (0xF4, 0xFF, 0xD6), W * 0.9)
    else:
        raise SystemExit(f"unknown option {option}")
    return img.convert("RGB").resize((1024, 1024), Image.LANCZOS)


if __name__ == "__main__":
    draw(sys.argv[1]).save(sys.argv[2])
