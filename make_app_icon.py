"""Build Windows application icon resources from the project logo.

Reads ../logo.png (non-square RGBA), centers it on a square transparent
canvas, then writes multi-size PNGs and a bundled multi-resolution .ico.
Run:  python make_app_icon.py
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
LOGO = HERE.parent / "logo.png"
OUT = HERE / "assets"
ICO_SIZES = [16, 32, 48, 64, 256]
PNG_SIZES = [16, 32, 48, 64, 128, 256]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = Image.open(LOGO).convert("RGBA")
    w, h = logo.size
    side = max(w, h)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(logo, ((side - w) // 2, (side - h) // 2), logo)

    master = OUT / "icon_master.png"
    square.save(master)

    for s in PNG_SIZES:
        square.resize((s, s), Image.LANCZOS).save(OUT / f"icon_{s}.png")

    icons = [square.resize((s, s), Image.LANCZOS) for s in ICO_SIZES]
    ico = OUT / "app.ico"
    icons[-1].save(ico, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
    print(f"wrote {master}")
    print(f"wrote {len(PNG_SIZES)} PNGs and {ico}")


if __name__ == "__main__":
    main()
