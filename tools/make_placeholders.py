#!/usr/bin/env python3
"""按 assets/manifest.json 生成占位图（渐变 + 剪影 + 文字），让游戏在没有正式美术时也能完整运行。

python tools/make_placeholders.py            # 只补缺失的
python tools/make_placeholders.py --force    # 全部重做
生成 image 2 正式图后，gen_assets.py 会覆盖同名文件。
"""
import argparse
import colorsys
import hashlib
import json
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT = ROOT / "assets" / "fonts" / "cjk.ttf"
SIZES = {"9:16": (720, 1280), "3:4": (768, 1024), "1:1": (768, 768), "16:9": (1280, 720)}
CHAR_COLORS = {"shen_yan": (79, 163, 255), "gu_ci": (201, 182, 255), "lu_zhuo": (255, 140, 102)}
CHAR_NAMES = {"shen_yan": "沈砚", "gu_ci": "顾辞", "lu_zhuo": "陆灼"}


def font(size):
    try:
        return ImageFont.truetype(str(FONT), size)
    except Exception:
        return ImageFont.load_default()


def hue_for(key):
    h = int(hashlib.md5(key.encode()).hexdigest(), 16)
    return (h % 360) / 360.0


def gradient(w, h, hue, sat=0.55):
    img = Image.new("RGB", (w, h))
    px = img.load()
    top = colorsys.hsv_to_rgb(hue, sat, 0.62)
    bottom = colorsys.hsv_to_rgb((hue + 0.1) % 1.0, sat + 0.15, 0.16)
    for y in range(h):
        t = y / max(1, h - 1)
        r = top[0] * (1 - t) + bottom[0] * t
        g = top[1] * (1 - t) + bottom[1] * t
        b = top[2] * (1 - t) + bottom[2] * t
        row = (int(r * 255), int(g * 255), int(b * 255))
        for x in range(w):
            px[x, y] = row
    return img


def add_glow(img, cx, cy, radius, color, alpha=120):
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=color + (alpha,))
    glow = glow.filter(ImageFilter.GaussianBlur(radius / 2))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"))


def draw_silhouette(img, color):
    w, h = img.size
    d = ImageDraw.Draw(img, "RGBA")
    cx = w // 2
    head_r = int(w * 0.14)
    head_y = int(h * 0.30)
    d.ellipse((cx - head_r, head_y - head_r, cx + head_r, head_y + head_r), fill=color + (235,))
    neck_top = head_y + head_r - 6
    shoulder_w = int(w * 0.36)
    d.rounded_rectangle((cx - shoulder_w, neck_top + 20, cx + shoulder_w, h), radius=int(w * 0.18), fill=color + (210,))
    # 发丝高光
    d.arc((cx - head_r, head_y - head_r, cx + head_r, head_y + head_r), 200, 340, fill=(255, 255, 255, 120), width=6)


def text_center(d, xy, text, size, fill=(255, 255, 255)):
    f = font(size)
    bbox = d.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((xy[0] - tw / 2, xy[1] - th / 2), text, font=f, fill=fill)


def make(entry, out):
    key = entry["key"]
    w, h = SIZES.get(entry.get("ratio", "9:16"), SIZES["9:16"])
    category = key.split("/")[0]
    char = entry.get("char")
    if char in CHAR_COLORS:
        base = CHAR_COLORS[char]
        hue = colorsys.rgb_to_hsv(*(c / 255 for c in base))[0]
    else:
        hue = hue_for(key)
    img = gradient(w, h, hue, 0.45 if category == "backgrounds" else 0.55)
    add_glow(img, int(w * 0.5), int(h * 0.35), int(min(w, h) * 0.45), (255, 255, 255), 70)
    d = ImageDraw.Draw(img, "RGBA")

    if category == "characters":
        draw_silhouette(img, CHAR_COLORS.get(char, (200, 200, 220)))
        d = ImageDraw.Draw(img, "RGBA")
        name = CHAR_NAMES.get(char, char)
        expr = key.split("/")[-1]
        text_center(d, (w / 2, h * 0.86), name, 72)
        text_center(d, (w / 2, h * 0.92), expr, 34, (230, 230, 240))
    elif category == "cards":
        d.rounded_rectangle((28, 28, w - 28, h - 28), radius=36, outline=(255, 255, 255, 140), width=4)
        draw_silhouette(img.crop((0, 0, w, h)), CHAR_COLORS.get(char, (200, 200, 220)))
        sil = Image.new("RGB", (w, h))
        sil.paste(img)
        draw_silhouette(sil, CHAR_COLORS.get(char, (200, 200, 220)))
        img.paste(sil)
        d = ImageDraw.Draw(img, "RGBA")
        text_center(d, (w / 2, h * 0.08), "思念 · " + CHAR_NAMES.get(char, ""), 40)
        text_center(d, (w / 2, h * 0.94), key.split("/")[-1], 28, (230, 230, 240))
    elif category == "enemies":
        d = ImageDraw.Draw(img, "RGBA")
        for i in range(6):
            r = int(w * (0.42 - i * 0.05))
            d.ellipse((w / 2 - r, h / 2 - r + i * 10, w / 2 + r, h / 2 + r + i * 10), fill=(10, 12, 30, 90))
        d.ellipse((w / 2 - 30, h / 2 - 30, w / 2 + 30, h / 2 + 30), fill=(120, 200, 255, 230))
        text_center(d, (w / 2, h * 0.9), key.split("/")[-1], 36)
    elif category == "ui":
        for i in range(40):
            x = (i * 97) % w
            y = (i * 53) % h
            d.ellipse((x, y, x + 4, y + 4), fill=(255, 255, 255, 180))
        text_center(d, (w * 0.3, h / 2), "卡池横幅", 64)
        text_center(d, (w * 0.3, h * 0.7), key.split("/")[-1], 30, (230, 230, 240))
    elif category == "moments":
        text_center(d, (w / 2, h / 2), "照片 · " + key.split("/")[-1], 44)
    else:
        for i in range(60):
            x = (i * 131) % w
            y = (i * 71) % int(h * 0.6)
            d.ellipse((x, y, x + 3, y + 3), fill=(255, 255, 255, 160))
        text_center(d, (w / 2, h * 0.5), key.split("/")[-1].replace("_", " "), 54)
        text_center(d, (w / 2, h * 0.5 + 70), "占位背景", 30, (230, 230, 240))

    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, "JPEG", quality=82, optimize=True)


def make_icon(out):
    img = gradient(512, 512, 0.52, 0.6)
    add_glow(img, 256, 200, 200, (255, 200, 220), 110)
    d = ImageDraw.Draw(img)
    text_center(d, (256, 230), "深", 200)
    text_center(d, (256, 420), "深与空恋", 56)
    img.save(out, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    manifest = json.loads((ROOT / "assets" / "manifest.json").read_text(encoding="utf-8"))
    made = 0
    for entry in manifest["assets"]:
        out = ROOT / "assets" / "gen" / (entry["key"] + ".jpg")
        png = out.with_suffix(".png")
        if (out.exists() or png.exists()) and not args.force:
            continue
        make(entry, out)
        made += 1
    icon = ROOT / "icon.png"
    if not icon.exists() or args.force:
        make_icon(icon)
    print(f"placeholders made: {made}")


if __name__ == "__main__":
    main()
