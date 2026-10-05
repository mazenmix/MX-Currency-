from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "MXCurrency" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 1024
GOLD = (255, 204, 26, 255)
GOLD_HI = (255, 225, 78, 255)

# Deep glossy black background, very close to the Currency Pro reference.
img = Image.new("RGBA", (SIZE, SIZE), (8, 8, 9, 255))
px = img.load()
for y in range(SIZE):
    for x in range(SIZE):
        dx = (x - SIZE / 2) / (SIZE / 2)
        dy = (y - SIZE * 0.42) / (SIZE / 2)
        d = min(1.0, (dx * dx + dy * dy) ** 0.5)
        lift = int(18 * (1.0 - d))
        top_glow = int(max(0, 10 * (1 - y / SIZE)))
        v = min(32, 8 + lift + top_glow)
        px[x, y] = (v, v, v + 1, 255)

# Soft top sheen.
sheen = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(sheen)
sd.ellipse((-80, -520, 1100, 430), fill=(255, 255, 255, 14))
sheen = sheen.filter(ImageFilter.GaussianBlur(70))
img = Image.alpha_composite(img, sheen)

draw = ImageDraw.Draw(img)

# Main gold ring.
ring_box = (176, 176, 848, 848)
draw.ellipse(ring_box, outline=GOLD, width=28)
# Fine highlight and lowlight to give the ring a premium metallic edge.
draw.ellipse((184, 184, 840, 840), outline=(255, 235, 120, 120), width=4)
draw.ellipse((169, 169, 855, 855), outline=(120, 76, 0, 90), width=3)

font_candidates = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttf",
]
font = None
for candidate in font_candidates:
    try:
        font = ImageFont.truetype(candidate, 500)
        break
    except Exception:
        pass
if font is None:
    font = ImageFont.load_default()

# Center the dollar sign precisely inside the circle.
text = "$"
bbox = draw.textbbox((0, 0), text, font=font, stroke_width=1)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
tx = (SIZE - tw) / 2 - bbox[0]
ty = (SIZE - th) / 2 - bbox[1] - 8

# Subtle shadow under the glyph.
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sh = ImageDraw.Draw(shadow)
sh.text((tx + 7, ty + 11), text, font=font, fill=(0, 0, 0, 180), stroke_width=2)
shadow = shadow.filter(ImageFilter.GaussianBlur(14))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

draw.text((tx, ty), text, font=font, fill=GOLD_HI, stroke_width=1, stroke_fill=GOLD)

master = img.convert("RGB")
master.save(OUT / "icon-1024.png", quality=96)
for px_size in [40, 58, 60, 80, 87, 120, 180]:
    master.resize((px_size, px_size), Image.Resampling.LANCZOS).save(
        OUT / f"icon-{px_size}.png", quality=96
    )

print(f"Generated black/gold currency icons in {OUT}")
