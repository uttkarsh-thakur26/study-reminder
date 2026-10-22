"""Draws the app icon and writes every size the platforms need.

Run from the repo root: python3 tool/make_icons.py (needs Pillow).
"""

from PIL import Image, ImageDraw

TOP = (99, 102, 241)  # indigo 500
BOTTOM = (67, 56, 202)  # indigo 700
WHITE = (255, 255, 255, 255)
AMBER = (251, 191, 36, 255)


def draw(size: int, badge: bool = True) -> Image.Image:
    s = 4  # draw large, then shrink for smooth edges
    n = size * s
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    gradient = Image.new("RGBA", (n, n))
    g = ImageDraw.Draw(gradient)
    for y in range(n):
        t = y / (n - 1)
        g.line(
            [(0, y), (n, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)) + (255,),
        )
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, n - 1, n - 1], radius=n * 0.225, fill=255)
    img.paste(gradient, (0, 0), mask)

    d = ImageDraw.Draw(img)
    u = n / 1024
    cx = n / 2
    # Bell: knob, dome, flared body, rim and clapper.
    d.ellipse([cx - 44 * u, 196 * u, cx + 44 * u, 284 * u], fill=WHITE)
    d.ellipse([cx - 200 * u, 250 * u, cx + 200 * u, 650 * u], fill=WHITE)
    # The sides leave the dome straight down, then flare out to the rim.
    steps = [i / 24 for i in range(25)]
    right = [(cx + (200 + 52 * t * t) * u, (450 + 262 * t) * u) for t in steps]
    left = [(cx - x + cx, y) for x, y in reversed(right)]
    d.polygon(right + left, fill=WHITE)
    d.rounded_rectangle([cx - 290 * u, 690 * u, cx + 290 * u, 762 * u], radius=36 * u, fill=WHITE)
    d.pieslice([cx - 76 * u, 700 * u, cx + 76 * u, 852 * u], 0, 180, fill=WHITE)
    if badge:
        d.ellipse([668 * u, 196 * u, 828 * u, 356 * u], fill=AMBER)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    big = draw(1024)
    big.save("tool/app_icon_1024.png")
    draw(256).save("assets/icons/app_icon.png")

    ico_sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    big.save("windows/runner/resources/app_icon.ico", sizes=[(x, x) for x in ico_sizes])
    # The tray icon is tiny, so leave out the badge.
    draw(256, badge=False).save(
        "assets/tray/tray_icon.ico", sizes=[(x, x) for x in [16, 20, 24, 32, 40, 48, 64]]
    )

    # Android launcher icons.
    for folder, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        draw(px).save(f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")


if __name__ == "__main__":
    main()
