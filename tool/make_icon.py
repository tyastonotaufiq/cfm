"""Draws the CFM app icon source images into assets/icon/.

A clay circle (the app's play button) on paper, with a pixel-art ♫ in the
middle. Colors match lib/app/theme.dart.

    python3 -m pip install Pillow
    python3 tool/make_icon.py
    dart run flutter_launcher_icons
"""

from pathlib import Path

from PIL import Image, ImageDraw

PAPER = (0xED, 0xEB, 0xE3, 255)
CLAY = (0xD9, 0x77, 0x57, 255)
CLEAR = (0, 0, 0, 0)

# ♫ on a pixel grid, '#' = filled.
NOTE = [
    "...########",
    "...########",
    "...##....##",
    "...##....##",
    "...##....##",
    "...##....##",
    "...##....##",
    ".####..####",
    "#####.#####",
    "#####.#####",
    "####..####.",
]

SIZE = 1024
SCALE = 4  # draw big, then shrink for smooth circle edges
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"


def draw_icon(background, circle, rounded=None):
    """background: fill color or CLEAR; circle: diameter as a share of SIZE;
    rounded: (inset, corner radius) of a paper rounded square, for macOS."""
    big = SIZE * SCALE
    img = Image.new("RGBA", (big, big), background)
    d = ImageDraw.Draw(img)

    if rounded:
        inset, radius = (v * SCALE for v in rounded)
        d.rounded_rectangle(
            (inset, inset, big - inset, big - inset), radius, fill=PAPER
        )

    r = big * circle / 2
    c = big / 2
    d.ellipse((c - r, c - r, c + r, c + r), fill=CLAY)

    # The note fills about half the circle; pixels are whole canvas pixels so
    # the shape stays crisp after shrinking.
    cols, rows = len(NOTE[0]), len(NOTE)
    px = int(r * 1.0 / max(cols, rows)) // SCALE * SCALE
    left = c - cols * px / 2 + px * 0.5  # nudge right: the heads sit left
    top = c - rows * px / 2
    for y, line in enumerate(NOTE):
        for x, ch in enumerate(line):
            if ch == "#":
                x0, y0 = left + x * px, top + y * px
                d.rectangle((x0, y0, x0 + px - 1, y0 + px - 1), fill=PAPER)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # iOS, web and older Android: full square, no transparency.
    draw_icon(PAPER, 0.70).save(OUT / "icon.png")
    # Android adaptive icon foreground: the system adds the paper background
    # and crops to its own shape, and flutter_launcher_icons insets it by 16%, so
    # this circle ends up about the same size as on the other platforms.
    draw_icon(CLEAR, 0.68).save(OUT / "icon_foreground.png")
    # macOS: rounded square with the standard margin, transparent outside.
    draw_icon(CLEAR, 0.56, rounded=(100, 185)).save(OUT / "icon_macos.png")


if __name__ == "__main__":
    main()
