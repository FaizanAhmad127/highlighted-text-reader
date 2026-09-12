#!/usr/bin/env python3
"""Compose Play / App Store marketing images from media/raw ss."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
RAW_PHONE = ROOT / "raw ss" / "phone"
RAW_TABLET = ROOT / "raw ss" / "tablet"
OUT_ANDROID_PHONE = ROOT / "android  store pics" / "phone"
OUT_ANDROID_TABLET = ROOT / "android  store pics" / "tablet"
OUT_IOS_IPHONE = ROOT / "ios store pics" / "iphone"
OUT_IOS_IPAD = ROOT / "ios store pics" / "ipad"

PHONE_SCREENS = [
    ("IMG_7499.jpg", "01-scan.png", "Snap a highlighted page", "Camera or gallery. That’s it."),
    ("IMG_7500.jpg", "02-meanings.png", "Every mark, explained", "Literal sense, and the line it lives in."),
    ("IMG_7501.jpg", "03-saved.png", "Keep the ones you need", "Search and reopen them anytime."),
    ("IMG_7502.jpg", "04-share.png", "Pass them to another phone", "One QR code. Thirty minutes."),
    ("IMG_7503.jpg", "05-language.png", "Meanings in your language", "English, Urdu, or the book’s own words."),
]

TABLET_SCREENS = [
    (
        "Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-09-12 at 19.14.28.png",
        "01-scan.png",
        "Snap a highlighted page",
        "Camera or gallery. That’s it.",
    ),
    (
        "Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-09-12 at 19.09.52.png",
        "02-meanings.png",
        "Every mark, explained",
        "Literal sense, and the line it lives in.",
    ),
    (
        "Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-09-12 at 19.10.43.png",
        "03-saved.png",
        "Keep the ones you need",
        "Search and reopen them anytime.",
    ),
    (
        "Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-09-12 at 19.10.59.png",
        "04-share.png",
        "Pass them to another device",
        "One QR code. Thirty minutes.",
    ),
    (
        "Simulator Screenshot - iPad Pro 13-inch (M4) - 2026-09-12 at 19.11.15.png",
        "05-language.png",
        "Meanings in your language",
        "English, Urdu, or the book’s own words.",
    ),
]

# Brand teal family, one tint per slide (Duolingo-style set, Headspace type).
BACKGROUNDS = [
    ((12, 42, 78), (18, 110, 82)),
    ((14, 52, 72), (22, 128, 88)),
    ((18, 40, 64), (16, 98, 78)),
    ((10, 32, 58), (14, 86, 90)),
    ((16, 48, 88), (20, 118, 86)),
]


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    names = (
        [
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/Library/Fonts/Arial Bold.ttf",
        ]
        if bold
        else [
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/Library/Fonts/Arial.ttf",
        ]
    )
    for path in names:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _gradient(size: tuple[int, int], top: tuple[int, int, int], bot: tuple[int, int, int]) -> Image.Image:
    w, h = size
    im = Image.new("RGB", size)
    px = im.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        # slight left-right shift so it matches the app icon
        for x in range(0, w, 4):
            u = x / max(w - 1, 1)
            mix = min(1.0, t * 0.82 + u * 0.18)
            color = tuple(int(top[i] + (bot[i] - top[i]) * mix) for i in range(3))
            for dx in range(4):
                if x + dx < w:
                    px[x + dx, y] = color
    return im


def _wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> str:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def _rounded(im: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(
    raw: Image.Image,
    title: str,
    subtitle: str,
    size: tuple[int, int],
    bg: tuple[tuple[int, int, int], tuple[int, int, int]],
    *,
    tablet: bool = False,
) -> Image.Image:
    w, h = size
    canvas = _gradient(size, bg[0], bg[1]).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    # Soft orbs, like Calm / Headspace backgrounds
    orb = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(orb)
    od.ellipse((-w * 0.15, -h * 0.08, w * 0.55, h * 0.28), fill=(255, 255, 255, 22))
    od.ellipse((w * 0.45, h * 0.72, w * 1.15, h * 1.12), fill=(0, 0, 0, 28))
    canvas = Image.alpha_composite(canvas, orb)
    draw = ImageDraw.Draw(canvas)

    title_size = max(40, int(h * (0.028 if tablet else 0.035)))
    sub_size = max(20, int(h * (0.014 if tablet else 0.018)))
    title_font = _font(title_size, bold=True)
    sub_font = _font(sub_size, bold=False)

    pad = int(w * 0.08)
    title_text = _wrap(draw, title, title_font, w - pad * 2)
    sub_text = _wrap(draw, subtitle, sub_font, w - pad * 2)

    title_bbox = draw.multiline_textbbox((0, 0), title_text, font=title_font, align="center", spacing=8)
    title_h = title_bbox[3] - title_bbox[1]
    draw.multiline_text(
        (w / 2, int(h * 0.055)),
        title_text,
        font=title_font,
        fill=(255, 255, 255),
        anchor="ma",
        align="center",
        spacing=8,
    )
    draw.multiline_text(
        (w / 2, int(h * 0.055) + title_h + int(h * 0.018)),
        sub_text,
        font=sub_font,
        fill=(230, 242, 236),
        anchor="ma",
        align="center",
        spacing=6,
    )

    # Phone sits in the lower ~68% with side margins
    top_text_end = int(h * 0.055) + title_h + int(h * 0.018) + int(sub_size * 2.4)
    avail_top = max(top_text_end + int(h * 0.02), int(h * 0.20))
    avail_bottom = h - int(h * 0.045)
    avail_h = avail_bottom - avail_top
    avail_w = w - pad * 2

    bezel = max(10, int(w * 0.014))
    radius = max(36, int(w * 0.055))
    src = raw.convert("RGB")
    scale = min(avail_w / (src.width + bezel * 2), avail_h / (src.height + bezel * 2))
    phone_inner = (
        max(1, int(src.width * scale)),
        max(1, int(src.height * scale)),
    )
    shot = src.resize(phone_inner, Image.Resampling.LANCZOS)
    phone_w = phone_inner[0] + bezel * 2
    phone_h = phone_inner[1] + bezel * 2
    phone = Image.new("RGBA", (phone_w, phone_h), (18, 22, 28, 255))
    phone = _rounded(phone, radius)
    inner = _rounded(shot, max(24, radius - bezel))
    phone.paste(inner, (bezel, bezel), inner)

    # Drop shadow
    shadow = Image.new("RGBA", (phone_w + 40, phone_h + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((12, 18, phone_w + 20, phone_h + 26), radius=radius + 4, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))

    px = (w - phone_w) // 2
    py = avail_top + max(0, (avail_h - phone_h) // 2)
    canvas.paste(shadow, (px - 16, py - 10), shadow)
    canvas.paste(phone, (px, py), phone)
    return canvas.convert("RGB")


def _write_set(
    screens: list[tuple[str, str, str, str]],
    raw_dir: Path,
    android_dir: Path,
    ios_dir: Path,
    android_size: tuple[int, int],
    ios_size: tuple[int, int],
    *,
    tablet: bool,
) -> None:
    android_dir.mkdir(parents=True, exist_ok=True)
    ios_dir.mkdir(parents=True, exist_ok=True)
    for i, (src_name, out_name, title, subtitle) in enumerate(screens):
        src_path = raw_dir / src_name
        if not src_path.exists():
            raise SystemExit(f"Missing {src_path}")
        raw = Image.open(src_path).convert("RGB")
        bg = BACKGROUNDS[i % len(BACKGROUNDS)]
        compose(raw, title, subtitle, android_size, bg, tablet=tablet).save(
            android_dir / out_name, "PNG", optimize=True
        )
        compose(raw, title, subtitle, ios_size, bg, tablet=tablet).save(
            ios_dir / out_name, "PNG", optimize=True
        )
        print(f"wrote {out_name}")


def main() -> None:
    only = sys.argv[1] if len(sys.argv) > 1 else "all"
    if only in ("all", "phone"):
        _write_set(
            PHONE_SCREENS,
            RAW_PHONE,
            OUT_ANDROID_PHONE,
            OUT_IOS_IPHONE,
            (1080, 1920),
            (1290, 2796),
            tablet=False,
        )
    if only in ("all", "tablet") and (
        any(RAW_TABLET.glob("*.png")) or any(RAW_TABLET.glob("*.jpg"))
    ):
        _write_set(
            TABLET_SCREENS,
            RAW_TABLET,
            OUT_ANDROID_TABLET,
            OUT_IOS_IPAD,
            (1600, 2560),
            (2064, 2752),
            tablet=True,
        )


if __name__ == "__main__":
    main()
