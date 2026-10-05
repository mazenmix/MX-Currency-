from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "MXCurrency" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), (3, 3, 4))

# Very subtle center lift so the black icon still has depth.
overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
for r in range(500, 0, -10):
    alpha = max(0, int(18 * (1 - r / 500)))
    od.ellipse((512-r, 512-r, 512+r, 512+r), fill=(35, 35, 38, alpha))
img = Image.alpha_composite(img.convert("RGBA"), overlay)

font_candidates = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Helvetica.ttc",
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

# Draw a compact MazenmiX-style MX monogram: white M + orange X on black.
draw = ImageDraw.Draw(img)
white = (248, 248, 250, 255)
orange = (255, 149, 0, 255)

# Shadow layer.
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.text((110, 250), "M", font=font, fill=(0, 0, 0, 190), stroke_width=2)
sd.text((510, 250), "X", font=font, fill=(0, 0, 0, 190), stroke_width=2)
shadow = shadow.filter(ImageFilter.GaussianBlur(18))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

draw.text((90, 225), "M", font=font, fill=white, stroke_width=1)
draw.text((495, 225), "X", font=font, fill=orange, stroke_width=1)

# Thin edge highlight only; iOS applies the rounded mask.
draw.rounded_rectangle((10, 10, 1014, 1014), radius=220, outline=(255, 255, 255, 20), width=2)

master = img.convert("RGB")
master.save(OUT / "icon-1024.png", quality=95)
for px in [40, 58, 60, 80, 87, 120, 180]:
    master.resize((px, px), Image.Resampling.LANCZOS).save(OUT / f"icon-{px}.png", quality=95)

print(f"Generated MX app icons in {OUT}")
