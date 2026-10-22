"""Builds the Kinnora brand kit: SVG logos (wordmark as outlined paths), PNG renders, icons,
colour tokens. Run: python3 build.py  (needs fontTools, Pillow, playwright+chromium)."""
import json, os, shutil
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))  # brand/
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-ExtraLight.ttf'

C = {
    'plum-900': '#120B1C', 'plum-800': '#1E1230', 'plum-700': '#341E48', 'plum-500': '#5B3A73',
    'gold-700': '#B8805A', 'gold-500': '#E2B48C', 'gold-300': '#FFE3C8',
    'star': '#FFECD6', 'glow': '#FFC9A6',
    'rose-300': '#D9A7A7', 'blush-100': '#F1D9D2', 'cream-50': '#F6F0E9',
    'ink-900': '#3C2428', 'sage-500': '#7F9A86',
}

font = TTFont(FONT)
gs = font.getGlyphSet(); cmap = font.getBestCmap(); upm = font['head'].unitsPerEm

def text_path(text, size, tracking_em=0.45):
    """SVG path data + width for `text` at `size` px, letters spaced by tracking_em."""
    scale = size / upm; x = 0; parts = []
    for i, ch in enumerate(text):
        g = gs[cmap[ord(ch)]]
        pen = SVGPathPen(gs)
        g.draw(TransformPen(pen, (scale, 0, 0, -scale, x, 0)))
        parts.append(pen.getCommands())
        x += g.width * scale + (tracking_em * size if i < len(text) - 1 else 0)
    return ' '.join(parts), x

def star_path(cx, cy, r, k=0.13):
    k *= r
    return (f"M{cx},{cy-r} Q{cx+k},{cy-k} {cx+r},{cy} Q{cx+k},{cy+k} {cx},{cy+r} "
            f"Q{cx-k},{cy+k} {cx-r},{cy} Q{cx-k},{cy-k} {cx},{cy-r} Z")

def defs(uid):
    return f'''<defs>
    <radialGradient id="bg{uid}" cx="50%" cy="42%" r="75%"><stop offset="0%" stop-color="{C['plum-700']}"/><stop offset="100%" stop-color="{C['plum-900']}"/></radialGradient>
    <linearGradient id="gold{uid}" x1="15%" y1="15%" x2="85%" y2="85%"><stop offset="0%" stop-color="{C['gold-700']}"/><stop offset="60%" stop-color="{C['gold-500']}"/><stop offset="100%" stop-color="{C['gold-300']}"/></linearGradient>
    <radialGradient id="sg{uid}" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#FFDCBE" stop-opacity="0.55"/><stop offset="100%" stop-color="#FFDCBE" stop-opacity="0"/></radialGradient>
    <filter id="bl{uid}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="{{blur}}"/></filter>
  </defs>'''

def mark(cx, cy, R, uid, glow=True, mono=None):
    """Ring + star. mono = single colour (no gradient, no glow) for one-colour use."""
    import math
    a0, a1 = math.radians(-10), math.radians(100)
    p0 = (cx + R * math.cos(a0), cy + R * math.sin(a0)); p1 = (cx + R * math.cos(a1), cy + R * math.sin(a1))
    arc = f"M {p0[0]:.1f} {p0[1]:.1f} A {R} {R} 0 0 1 {p1[0]:.1f} {p1[1]:.1f}"
    sw = R * 0.036; sr = R * 0.39
    if mono:
        return (f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="none" stroke="{mono}" stroke-width="{sw:.1f}"/>'
                f'<path d="{star_path(cx, cy, sr)}" fill="{mono}"/>')
    g = ''
    if glow:
        g = (f'<path d="{arc}" fill="none" stroke="{C["glow"]}" stroke-width="{R*0.117:.1f}" stroke-linecap="round" stroke-opacity="0.5" filter="url(#bl{uid})"/>'
             f'<path d="{arc}" fill="none" stroke="#FFE6D2" stroke-width="{R*0.052:.1f}" stroke-linecap="round" stroke-opacity="0.55"/>'
             f'<circle cx="{cx}" cy="{cy}" r="{R*0.62:.1f}" fill="url(#sg{uid})"/>')
    return (g + f'<circle cx="{cx}" cy="{cy}" r="{R}" fill="none" stroke="url(#gold{uid})" stroke-width="{sw:.1f}"/>'
            f'<path d="{star_path(cx, cy, sr)}" fill="{C["star"]}"/>')

def svg(w, h, body, uid, blur):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n  '
            + defs(uid).replace('{blur}', str(blur)) + '\n  ' + body + '\n</svg>\n')

def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'w').write(content)

files = {}
# --- marks
files['logo/kinora-mark-on-plum.svg'] = svg(1024, 1024, f'<rect width="1024" height="1024" fill="url(#bgA)"/>' + mark(512, 512, 307, 'A'), 'A', 22)
files['logo/kinora-mark.svg'] = svg(1024, 1024, mark(512, 512, 307, 'B'), 'B', 22)
files['logo/kinora-mark-gold-mono.svg'] = svg(1024, 1024, mark(512, 512, 307, 'C', mono=C['gold-700']), 'C', 22)
files['logo/kinora-mark-ink-mono.svg'] = svg(1024, 1024, mark(512, 512, 307, 'D', mono=C['ink-900']), 'D', 22)
files['logo/kinora-mark-white-mono.svg'] = svg(1024, 1024, mark(512, 512, 307, 'E', mono='#FFFFFF'), 'E', 22)

# --- lockups (wordmark as outlined paths)
def wordmark(color, size, cx, baseline):
    d, w = text_path('KINNORA', size)
    return f'<path d="{d}" fill="{color}" transform="translate({cx - w/2:.1f},{baseline})"/>', w

def tagline(color, size, cx, baseline, text='FEEL  ·  ALIGN  ·  BECOME'):
    d, w = text_path(text, size, tracking_em=0.18)
    return f'<path d="{d}" fill="{color}" transform="translate({cx - w/2:.1f},{baseline})"/>'

for variant, bgfill, ink, tag, uid, glow, mono in [
    ('dark', 'url(#bgF)', C['star'], C['gold-500'], 'F', True, None),
    ('light', C['cream-50'], C['ink-900'], C['gold-700'], 'G', False, C['gold-700']),
]:
    W, H = 1600, 1000
    wm, _ = wordmark(ink, 150, W / 2, 700)
    body = f'<rect width="{W}" height="{H}" fill="{bgfill}"/>' + mark(W / 2, 330, 190, uid, glow=glow, mono=mono) + wm + tagline(tag, 38, W / 2, 830)
    files[f'logo/kinora-logo-stacked-{variant}.svg'] = svg(W, H, body, uid, 16)
    # horizontal lockup, transparent
    W2, H2 = 1400, 360
    d, w = text_path('KINNORA', 120)
    x0 = 360
    body2 = mark(180, 180, 130, uid + 'h', glow=glow, mono=mono) + f'<path d="{d}" fill="{ink}" transform="translate({x0},{180 + 120*0.36:.1f})"/>'
    files[f'logo/kinora-logo-horizontal-{variant}.svg'] = svg(int(x0 + w + 60), H2, body2, uid + 'h', 12)
    # wordmark only
    d3, w3 = text_path('KINNORA', 200)
    files[f'logo/kinora-wordmark-{variant}.svg'] = svg(int(w3 + 40), 240, f'<path d="{d3}" fill="{ink}" transform="translate(20,{200*0.86:.0f})"/>', uid + 'w', 10)

for k, v in files.items(): write(f'{OUT}/{k}', v)

# --- colour tokens
tokens = {
    'brand': {'name': 'Kinnora', 'tagline': 'Feel · Align · Become'},
    'color': {
        'plum': {'900': C['plum-900'], '800': C['plum-800'], '700': C['plum-700'], '500': C['plum-500']},
        'gold': {'700': C['gold-700'], '500': C['gold-500'], '300': C['gold-300']},
        'star': C['star'], 'glow': C['glow'],
        'rose': {'300': C['rose-300']}, 'blush': {'100': C['blush-100']}, 'cream': {'50': C['cream-50']},
        'ink': {'900': C['ink-900']}, 'sage': {'500': C['sage-500']},
    },
    'gradient': {
        'ground': [C['plum-700'], C['plum-900']],
        'gold': [C['gold-700'], C['gold-500'], C['gold-300']],
    },
}
write(f'{OUT}/colors/tokens.json', json.dumps(tokens, indent=2) + '\n')
css = ':root {\n' + ''.join(f'  --kinora-{k}: {v};\n' for k, v in C.items()) + \
      f'  --kinora-gradient-ground: radial-gradient(75% 75% at 50% 42%, {C["plum-700"]}, {C["plum-900"]});\n' + \
      f'  --kinora-gradient-gold: linear-gradient(135deg, {C["gold-700"]}, {C["gold-500"]} 60%, {C["gold-300"]});\n}}\n'
write(f'{OUT}/colors/kinora.css', css)
def camel(k):
    a, *b = k.split('-'); return a + ''.join(x.capitalize() for x in b)
swift = ('import SwiftUI\n\n/// Kinnora brand colours (brand/colors/tokens.json).\nenum KinoraColor {\n'
         + ''.join(f'    static let {camel(k)} = Color(red: {int(v[1:3],16)/255:.3f}, green: {int(v[3:5],16)/255:.3f}, blue: {int(v[5:7],16)/255:.3f}) // {v}\n' for k, v in C.items())
         + '}\n')
write(f'{OUT}/colors/KinoraColor.swift', swift)
kt = ('package com.pulseloop.brand\n\nimport androidx.compose.ui.graphics.Color\n\n/** Kinnora brand colours (brand/colors/tokens.json). */\nobject KinoraColor {\n'
      + ''.join(f'    val {camel(k)} = Color(0xFF{v[1:].upper()})\n' for k, v in C.items()) + '}\n')
write(f'{OUT}/colors/KinoraColor.kt', kt)

# --- renders via Chromium
from playwright.sync_api import sync_playwright
renders = [
    ('logo/kinora-mark-on-plum.svg', 'png/kinora-mark-on-plum-1024.png', 1024, 1024, False),
    ('logo/kinora-mark.svg', 'png/kinora-mark-1024.png', 1024, 1024, True),
    ('logo/kinora-mark-gold-mono.svg', 'png/kinora-mark-gold-mono-1024.png', 1024, 1024, True),
    ('logo/kinora-logo-stacked-dark.svg', 'png/kinora-logo-stacked-dark.png', 1600, 1000, False),
    ('logo/kinora-logo-stacked-light.svg', 'png/kinora-logo-stacked-light.png', 1600, 1000, False),
]
with sync_playwright() as p:
    b = p.chromium.launch()
    for src, dst, w, h, transparent in renders:
        pg = b.new_page(viewport={'width': w, 'height': h})
        pg.set_content(f'<html><body style="margin:0;background:transparent">{open(f"{OUT}/{src}").read()}</body></html>')
        os.makedirs(os.path.dirname(f'{OUT}/{dst}'), exist_ok=True)
        pg.screenshot(path=f'{OUT}/{dst}', omit_background=transparent, clip={'x': 0, 'y': 0, 'width': w, 'height': h})
        pg.close()
    # horizontal lockups at natural size
    for v in ('dark', 'light'):
        s = open(f'{OUT}/logo/kinora-logo-horizontal-{v}.svg').read()
        import re
        w = int(re.search(r'width="(\d+)"', s).group(1))
        pg = b.new_page(viewport={'width': w, 'height': 360})
        pg.set_content(f'<html><body style="margin:0;background:transparent">{s}</body></html>')
        pg.screenshot(path=f'{OUT}/png/kinora-logo-horizontal-{v}.png', omit_background=True, clip={'x': 0, 'y': 0, 'width': w, 'height': 360})
        pg.close()
    # social: 1200x630 card, 400x400 avatar
    og = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">{defs("S").replace("{blur}", "12")}
      <rect width="1200" height="630" fill="url(#bgS)"/>{mark(600, 225, 120, "S")}{wordmark(C["star"], 90, 600, 470)[0]}{tagline(C["gold-500"], 26, 600, 545)}</svg>'''
    write(f'{OUT}/logo/kinora-social-card.svg', og)
    pg = b.new_page(viewport={'width': 1200, 'height': 630}); pg.set_content(f'<html><body style="margin:0">{og}</body></html>')
    pg.screenshot(path=f'{OUT}/social/kinora-social-card-1200x630.png', clip={'x': 0, 'y': 0, 'width': 1200, 'height': 630}); pg.close()
    b.close()

# --- icons from the plum mark
big = Image.open(f'{OUT}/png/kinora-mark-on-plum-1024.png').convert('RGB')
os.makedirs(f'{OUT}/icons', exist_ok=True)
big.save(f'{OUT}/icons/app-icon-1024.png')
for s in (512, 192, 180, 167, 152, 120, 87, 80, 64, 58, 48, 40, 32, 16):
    big.resize((s, s), Image.LANCZOS).save(f'{OUT}/icons/app-icon-{s}.png')
big.resize((400, 400), Image.LANCZOS).save(f'{OUT}/social/kinora-avatar-400.png')
big.resize((48, 48), Image.LANCZOS).save(f'{OUT}/icons/favicon.ico', sizes=[(16, 16), (32, 32), (48, 48)])
print('built', sum(len(f) for _, _, f in os.walk(OUT)), 'files')
