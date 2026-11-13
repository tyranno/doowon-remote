# 두원 원격지원 아이콘·로고 생성: py -3 brand/make_assets.py (저장소 루트에서)
from functools import lru_cache
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
C1, C2 = (0x2A, 0x9B, 0xB8), (0x1D, 0x3F, 0x73)
FONT_B = "C:/Windows/Fonts/malgunbd.ttf"
FONT_R = "C:/Windows/Fonts/malgun.ttf"

SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2A9BB8"/><stop offset="1" stop-color="#1D3F73"/></linearGradient></defs>
  <rect width="64" height="64" rx="14" fill="url(#g)"/>
  <rect x="11" y="14" width="42" height="28" rx="3.5" fill="none" stroke="#fff" stroke-width="4"/>
  <path d="M25 51h14M32 42v9" stroke="#fff" stroke-width="4" stroke-linecap="round"/>
  <path d="M27 20l12 6.5-5.2 1.4 3 5.4-2.6 1.4-3-5.4-3.9 3.7z" fill="#fff"/>
</svg>
"""


@lru_cache
def base() -> Image.Image:
    s = 1024
    k = s / 64
    grad = Image.new("RGB", (s, s))
    px = grad.load()
    for y in range(s):
        for x in range(s):
            t = (x + y) / (2 * (s - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(C1, C2))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=14 * k, fill=255)
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    im.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(im)
    w = round(4 * k)
    d.rounded_rectangle([11 * k, 14 * k, 53 * k, 42 * k], radius=3.5 * k, outline="white", width=w)
    d.line([32 * k, 42 * k, 32 * k, 51 * k], fill="white", width=w)
    d.line([25 * k, 51 * k, 39 * k, 51 * k], fill="white", width=w)
    for x, y in ((25 * k, 51 * k), (39 * k, 51 * k)):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill="white")
    cursor = [(27, 20), (39, 26.5), (33.8, 27.9), (36.8, 33.3), (34.2, 34.7), (31.2, 29.3), (27.3, 33)]
    d.polygon([(x * k, y * k) for x, y in cursor], fill="white")
    return im


def icon(size: int) -> Image.Image:
    return base().resize((size, size), Image.LANCZOS)


def logo() -> Image.Image:
    # Flutter 홈 화면 로고(최대 300x60) — 2배 해상도
    h, pad = 120, 8
    title = ImageFont.truetype(FONT_B, 46)
    sub = ImageFont.truetype(FONT_R, 26)
    t1, t2 = "두원전자통신", "원격지원 서비스"
    tw = max(title.getlength(t1), sub.getlength(t2))
    ic = h - 2 * pad
    im = Image.new("RGBA", (int(ic + 24 + tw + 2 * pad), h), (0, 0, 0, 0))
    im.alpha_composite(icon(ic), (pad, pad))
    d = ImageDraw.Draw(im)
    x = pad + ic + 24
    d.text((x, 8), t1, font=title, fill=(0x1D, 0x3F, 0x73))
    d.text((x, 70), t2, font=sub, fill=(0x2A, 0x9B, 0xB8))
    return im


def label() -> Image.Image:
    # 포터블 압축 해제 화면의 글자(원본과 같은 96x32, 흰 글자)
    im = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT_B, 15)
    t = "두원 원격지원"
    ImageDraw.Draw(im).text(((96 - f.getlength(t)) / 2, 6), t, font=f, fill="white")
    return im


def main():
    label().save(ROOT / "libs/portable/src/res/label.png")
    (ROOT / "flutter/assets/icon.svg").write_text(SVG, encoding="utf-8")
    (ROOT / "brand/icon.svg").write_text(SVG, encoding="utf-8")
    logo().save(ROOT / "flutter/assets/logo.png")
    big = icon(256)
    sizes = [(n, n) for n in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
    for p in ("res/icon.ico", "res/tray-icon.ico", "flutter/windows/runner/resources/app_icon.ico"):
        big.save(ROOT / p, sizes=sizes)
    for p, n in (("res/icon.png", 256), ("res/32x32.png", 32), ("res/64x64.png", 64),
                 ("res/128x128.png", 128), ("res/128x128@2x.png", 256), ("brand/icon-512.png", 512)):
        icon(n).save(ROOT / p)


if __name__ == "__main__":
    main()
