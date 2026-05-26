from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "icons"
OUT.mkdir(parents=True, exist_ok=True)

EMOJI = "💜"  # change to "L", "🚀", "⬇️", etc.
SIZES = [16, 48, 128]

def get_font(size):
    candidates = [
        "C:/Windows/Fonts/seguiemj.ttf",  # Windows emoji
        "C:/Windows/Fonts/segoeui.ttf",
        "/System/Library/Fonts/Apple Color Emoji.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()

for size in SIZES:
    img = Image.new("RGBA", (size, size), (20, 20, 28, 255))
    draw = ImageDraw.Draw(img)

    font = get_font(int(size * 0.72))
    bbox = draw.textbbox((0, 0), EMOJI, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]

    x = (size - w) / 2 - bbox[0]
    y = (size - h) / 2 - bbox[1]

    draw.text((x, y), EMOJI, font=font, fill=(255, 255, 255, 255))

    img.save(OUT / f"icon{size}.png")

print(f"Generated icons in {OUT}")