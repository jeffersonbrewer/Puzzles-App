"""Draws the app icon and its alternates into Puzzles/Assets.xcassets.
Run from the repository root: python3 tools/make_icons.py  (needs Pillow)."""
import json, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
ASSETS = 'Puzzles/Assets.xcassets'
FONT = None
for f in ['/System/Library/Fonts/SFNSRounded.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/Library/Fonts/Arial Bold.ttf']:
    if os.path.exists(f):
        FONT = f
        break

def font(size):
    return ImageFont.truetype(FONT, size) if FONT else ImageFont.load_default()

def gradient(top, bottom):
    img = Image.new('RGB', (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img

# (row, col, digit) inside a single 3x3 box; the highlighted cell is drawn in the accent.
DIGITS = [(0, 0, 5), (0, 2, 3), (1, 1, 7), (2, 0, 8), (2, 2, 1)]
HIGHLIGHT = (1, 2, 9)

def board_icon(top, bottom, paper, line, ink, accent, accent_text=(255, 255, 255), margin=190, shadow=True):
    img = gradient(top, bottom)
    g = S - 2 * margin
    if shadow:
        sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([margin, margin + 20, S - margin, S - margin + 20], radius=70, fill=(0, 0, 0, 80))
        blurred = sh.filter(ImageFilter.GaussianBlur(26))
        img.paste(blurred, (0, 0), blurred)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([margin, margin, S - margin, S - margin], radius=70, fill=paper)
    cell = g / 3
    r, c, v = HIGHLIGHT
    inset = 18
    d.rounded_rectangle([margin + c * cell + inset, margin + r * cell + inset, margin + (c + 1) * cell - inset, margin + (r + 1) * cell - inset], radius=30, fill=accent)
    for k in (1, 2):
        x = margin + cell * k
        d.line([(x, margin + 30), (x, S - margin - 30)], fill=line, width=10)
        d.line([(margin + 30, x), (S - margin - 30, x)], fill=line, width=10)
    f = font(int(cell * 0.62))
    for (r, c, v) in DIGITS:
        d.text((margin + c * cell + cell / 2, margin + r * cell + cell / 2), str(v), font=f, fill=ink, anchor='mm')
    r, c, v = HIGHLIGHT
    d.text((margin + c * cell + cell / 2, margin + r * cell + cell / 2), str(v), font=f, fill=accent_text, anchor='mm')
    return img

def big_grid_icon(bg, line, fill_cell, digit_color, text='9'):
    img = Image.new('RGB', (S, S), bg)
    d = ImageDraw.Draw(img)
    m = 230
    g = S - 2 * m
    cell = g / 3
    d.rounded_rectangle([m + cell, m + cell, m + 2 * cell, m + 2 * cell], radius=28, fill=fill_cell)
    for k in range(0, 4):
        x = m + cell * k
        d.line([(x, m), (x, S - m)], fill=line, width=16)
        d.line([(m, x), (S - m, x)], fill=line, width=16)
    d.text((S / 2, S / 2), text, font=font(int(cell * 0.8)), fill=digit_color, anchor='mm')
    return img

ICONS = {
    'AppIcon': ('Teal', board_icon((40, 140, 160), (20, 75, 110), (250, 247, 240), (200, 208, 210), (35, 55, 65), (31, 122, 140))),
    'AppIcon-Forest': ('Forest', board_icon((60, 140, 85), (18, 70, 45), (246, 243, 232), (200, 205, 190), (30, 55, 38), (40, 120, 65))),
    'AppIcon-Midnight': ('Midnight', board_icon((32, 40, 72), (8, 10, 22), (24, 30, 54), (60, 72, 110), (215, 222, 245), (90, 190, 215), accent_text=(10, 20, 35))),
    'AppIcon-Paper': ('Paper', board_icon((248, 243, 232), (234, 223, 200), (255, 253, 248), (222, 212, 195), (60, 50, 45), (214, 98, 72), shadow=False)),
    'AppIcon-Sunset': ('Sunset', board_icon((246, 150, 96), (178, 58, 98), (255, 248, 242), (232, 210, 205), (90, 40, 50), (205, 72, 88))),
    'AppIcon-Mono': ('Mono', big_grid_icon((18, 18, 20), (235, 235, 235), (31, 122, 140), (255, 255, 255))),
}

def write(name, img):
    folder = os.path.join(ASSETS, name + '.appiconset')
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + '.png'))
    with open(os.path.join(folder, 'Contents.json'), 'w') as fh:
        json.dump({'images': [{'filename': name + '.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
                   'info': {'author': 'xcode', 'version': 1}}, fh, indent=2)

def write_preview(name, img):
    # App icon sets can't be shown inside the app, so each icon also gets a
    # small image set the icon picker can display.
    folder = os.path.join(ASSETS, 'IconPreview-' + name + '.imageset')
    os.makedirs(folder, exist_ok=True)
    img.resize((240, 240), Image.LANCZOS).save(os.path.join(folder, 'preview.png'))
    with open(os.path.join(folder, 'Contents.json'), 'w') as fh:
        json.dump({'images': [{'filename': 'preview.png', 'idiom': 'universal'}],
                   'info': {'author': 'xcode', 'version': 1}}, fh, indent=2)

def preview_sheet(path):
    tile, pad = 300, 50
    names = list(ICONS)
    sheet = Image.new('RGB', (len(names) * (tile + pad) + pad, tile + pad * 2 + 60), (236, 239, 241))
    d = ImageDraw.Draw(sheet)
    mask = Image.new('L', (tile, tile), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1], radius=int(tile * 0.225), fill=255)
    for k, n in enumerate(names):
        label, img = ICONS[n]
        x = pad + k * (tile + pad)
        sheet.paste(img.resize((tile, tile), Image.LANCZOS), (x, pad), mask)
        d.text((x + tile / 2, pad + tile + 34), label, font=font(30), fill=(40, 50, 55), anchor='mm')
    sheet.save(path)

if __name__ == '__main__':
    import sys
    if os.path.exists('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    for n, (_, img) in ICONS.items():
        write(n, img)
        write_preview(n, img)
    if len(sys.argv) > 1:
        preview_sheet(sys.argv[1])
