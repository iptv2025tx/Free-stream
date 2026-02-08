"""Generate Roku channel images: posters and splash screens."""
from PIL import Image, ImageDraw, ImageFont
import os

IMAGES_DIR = os.path.join(os.path.dirname(__file__), "images")

BG_COLOR = (26, 26, 46)       # #1A1A2E
ACCENT_COLOR = (0, 212, 255)  # #00D4FF
TEXT_COLOR = (255, 255, 255)
DARK_PANEL = (15, 52, 96)     # #0F3460


def draw_rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    draw.rectangle([x0 + radius, y0, x1 - radius, y1], fill=fill)
    draw.rectangle([x0, y0 + radius, x1, y1 - radius], fill=fill)
    draw.pieslice([x0, y0, x0 + 2 * radius, y0 + 2 * radius], 180, 270, fill=fill)
    draw.pieslice([x1 - 2 * radius, y0, x1, y0 + 2 * radius], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2 * radius, x0 + 2 * radius, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2 * radius, y1 - 2 * radius, x1, y1], 0, 90, fill=fill)


def draw_tv_icon(draw, cx, cy, size, color):
    """Draw a simple TV icon."""
    w = size
    h = int(size * 0.65)
    x0 = cx - w // 2
    y0 = cy - h // 2
    # TV body
    draw_rounded_rect(draw, (x0, y0, x0 + w, y0 + h), size // 10, color)
    # Screen (inner)
    margin = size // 8
    screen_color = BG_COLOR
    draw.rectangle([x0 + margin, y0 + margin, x0 + w - margin, y0 + h - margin], fill=screen_color)
    # Play triangle on screen
    tri_size = size // 5
    tri_cx = cx
    tri_cy = cy - size // 20
    pts = [
        (tri_cx - tri_size // 2, tri_cy - tri_size // 2),
        (tri_cx - tri_size // 2, tri_cy + tri_size // 2),
        (tri_cx + tri_size // 2, tri_cy),
    ]
    draw.polygon(pts, fill=color)
    # Stand
    stand_w = size // 3
    stand_h = size // 12
    draw.rectangle([cx - stand_w // 2, y0 + h, cx + stand_w // 2, y0 + h + stand_h], fill=color)


def create_poster(width, height, filename):
    """Create channel poster icon."""
    img = Image.new("RGBA", (width, height), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    # Border glow
    draw.rectangle([0, 0, width - 1, height - 1], outline=ACCENT_COLOR, width=3)

    # TV icon
    icon_size = min(width, height) // 2
    draw_tv_icon(draw, width // 2, height // 2 - 15, icon_size, ACCENT_COLOR)

    # Text "IPTV Player"
    try:
        font_big = ImageFont.truetype("arial.ttf", max(16, height // 7))
        font_small = ImageFont.truetype("arial.ttf", max(12, height // 10))
    except OSError:
        font_big = ImageFont.load_default()
        font_small = ImageFont.load_default()

    # "IPTV" text
    text = "IPTV"
    bbox = draw.textbbox((0, 0), text, font=font_big)
    tw = bbox[2] - bbox[0]
    draw.text((width // 2 - tw // 2, height - 55), text, fill=ACCENT_COLOR, font=font_big)

    # "Player" text
    text2 = "Player"
    bbox2 = draw.textbbox((0, 0), text2, font=font_small)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((width // 2 - tw2 // 2, height - 30), text2, fill=TEXT_COLOR, font=font_small)

    img.save(os.path.join(IMAGES_DIR, filename))
    print(f"Created {filename} ({width}x{height})")


def create_splash(width, height, filename):
    """Create splash screen."""
    img = Image.new("RGBA", (width, height), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    # Central panel
    pw, ph = width // 3, height // 3
    px = width // 2 - pw // 2
    py = height // 2 - ph // 2
    draw_rounded_rect(draw, (px, py, px + pw, py + ph), 20, DARK_PANEL + (200,))

    # TV icon
    icon_size = min(pw, ph) // 2
    draw_tv_icon(draw, width // 2, height // 2 - 30, icon_size, ACCENT_COLOR)

    try:
        font_title = ImageFont.truetype("arial.ttf", max(24, height // 15))
        font_sub = ImageFont.truetype("arial.ttf", max(16, height // 25))
    except OSError:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # "IPTV Player"
    title = "IPTV Player"
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    draw.text((width // 2 - tw // 2, height // 2 + 40), title, fill=ACCENT_COLOR, font=font_title)

    # "Canais ao vivo"
    sub = "Canais ao vivo"
    bbox2 = draw.textbbox((0, 0), sub, font=font_sub)
    tw2 = bbox2[2] - bbox2[0]
    draw.text((width // 2 - tw2 // 2, height // 2 + 85), sub, fill=TEXT_COLOR, font=font_sub)

    img.save(os.path.join(IMAGES_DIR, filename))
    print(f"Created {filename} ({width}x{height})")


if __name__ == "__main__":
    os.makedirs(IMAGES_DIR, exist_ok=True)

    # Channel posters (Roku requirements)
    create_poster(336, 210, "channel-poster_hd.png")   # HD poster: 336x210
    create_poster(246, 140, "channel-poster_sd.png")   # SD poster: 246x140

    # Splash screens
    create_splash(1280, 720, "splash-screen_hd.png")    # HD: 1280x720
    create_splash(1920, 1080, "splash-screen_fhd.png")  # FHD: 1920x1080

    print("All images created successfully!")
