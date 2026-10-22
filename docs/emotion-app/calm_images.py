import numpy as np, math, sys
from PIL import Image, ImageFilter, ImageDraw

W, H = 1080, 1920
rng = np.random.default_rng(7)

def lerp(a, b, t): return a + (b - a) * t
def hexc(h): h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], float)

def vgrad(stops, h=H, w=W):
    """stops: list of (pos 0..1, hex)"""
    ys = np.linspace(0, 1, h)
    out = np.zeros((h, 3))
    for c in range(3):
        out[:, c] = np.interp(ys, [s[0] for s in stops], [hexc(s[1])[c] for s in stops])
    return np.repeat(out[:, None, :], w, axis=1)

def glow(img, cx, cy, r, color, strength=1.0):
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    a = np.exp(-d ** 2) * strength
    return img + a[..., None] * hexc(color)[None, None, :] * 0.6

def disc(img, cx, cy, r, color, soft=2.0):
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    a = np.clip((r - d) / soft, 0, 1)
    return img * (1 - a[..., None]) + hexc(color) * a[..., None]

def ridge(n, rough=0.55, seed=0, amp=1.0):
    r = np.random.default_rng(seed)
    size = 1
    pts = np.array([r.uniform(-1, 1), r.uniform(-1, 1)])
    scale = amp
    while len(pts) < n:
        mids = (pts[:-1] + pts[1:]) / 2 + r.uniform(-scale, scale, len(pts) - 1)
        new = np.empty(len(pts) * 2 - 1)
        new[0::2] = pts; new[1::2] = mids
        pts = new; scale *= rough
    xs = np.linspace(0, 1, len(pts))
    return np.interp(np.linspace(0, 1, n), xs, pts)

def mountains(img, base_y, height, color, seed, rough=0.55, mist=None, mist_h=160, alpha=1.0):
    h, w, _ = img.shape
    r = ridge(w, rough, seed)
    r = (r - r.min()) / (r.max() - r.min() + 1e-9)
    top = base_y - r * height
    yy = np.arange(h)[:, None]
    a = np.clip((yy - top[None, :]) / 1.5, 0, 1) * alpha
    col = hexc(color)
    img = img * (1 - a[..., None]) + col * a[..., None]
    if mist:
        m = np.clip(1 - (yy - base_y + mist_h) / mist_h, 0, 1) * np.clip((yy - (base_y - mist_h)) / mist_h, 0, 1)
        m = m * (yy <= base_y + 10)
        img = img * (1 - 0.55 * m[..., None]) + hexc(mist) * 0.55 * m[..., None]
    return img, top

def stars(img, n, ymax, seed=1, bright=1.0):
    r = np.random.default_rng(seed)
    for _ in range(n):
        x, y = r.integers(0, img.shape[1]), r.integers(0, int(ymax))
        s = r.uniform(0.3, 1.0) * bright
        img[y, x] = np.minimum(255, img[y, x] + 255 * s)
        if s > 0.8 and 1 <= x < img.shape[1] - 1 and 1 <= y < img.shape[0] - 1:
            img[y-1:y+2, x] = np.minimum(255, img[y-1:y+2, x] + 120 * s)
            img[y, x-1:x+2] = np.minimum(255, img[y, x-1:x+2] + 120 * s)
    return img

def reflect(img, horizon, strength=0.55, tint='#0b1424', ripple=True, seed=3):
    h, w, _ = img.shape
    above = img[:horizon][::-1]
    n = min(h - horizon, horizon)
    refl = above[:n].copy()
    if ripple:
        r = np.random.default_rng(seed)
        out = np.empty_like(refl)
        for y in range(n):
            amp = 1 + y * 0.012
            shift = int(round(np.sin(y * 0.22 + r.uniform(0, 0.3)) * amp))
            out[y] = np.roll(refl[y], shift, axis=0)
        refl = out
    refl = np.asarray(Image.fromarray(np.clip(refl, 0, 255).astype('uint8')).filter(ImageFilter.GaussianBlur(3))).astype(float)
    t = hexc(tint)
    fade = np.linspace(strength, strength * 0.35, n)[:, None, None]
    img[horizon:horizon + n] = refl * fade + t * (1 - fade)
    if horizon + n < h:
        img[horizon + n:] = t
    return img

def water_lines(img, y0, y1, color, count, seed=5, alpha=0.35, maxlen=260):
    r = np.random.default_rng(seed)
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8'))
    over = Image.new('RGBA', pil.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    c = tuple(int(v) for v in hexc(color))
    for _ in range(count):
        y = r.uniform(y0, y1)
        depth = (y - y0) / max(1, (y1 - y0))
        L = r.uniform(30, maxlen) * (0.4 + depth)
        x = r.uniform(-50, W)
        d.line([(x, y), (x + L, y)], fill=c + (int(255 * alpha * r.uniform(0.4, 1)),), width=max(1, int(1 + depth * 3)))
    pil = Image.alpha_composite(pil.convert('RGBA'), over.filter(ImageFilter.GaussianBlur(1.2))).convert('RGB')
    return np.asarray(pil).astype(float)

def blur(img, r):
    return np.asarray(Image.fromarray(np.clip(img, 0, 255).astype('uint8')).filter(ImageFilter.GaussianBlur(r))).astype(float)

def grain(img, amt=4, seed=9):
    r = np.random.default_rng(seed)
    return img + r.normal(0, amt, img.shape)

def vignette(img, s=0.35):
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    return img * (1 - s * np.clip(d - 0.55, 0, 1)[..., None])

def monk(img, cx, base_y, scale, color='#0a0d14', rim=None):
    """Seated meditating figure (lotus pose) as a soft silhouette."""
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8')).convert('RGBA')
    S = 4
    over = Image.new('RGBA', (pil.width * S, pil.height * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    c = tuple(int(v) for v in hexc(color)) + (255,)
    s = scale * S; x0 = cx * S; y0 = base_y * S
    half = [(1.10, 0.00), (1.08, -0.12), (0.95, -0.24), (0.74, -0.32), (0.66, -0.42), (0.64, -0.58),
            (0.60, -0.78), (0.54, -0.98), (0.44, -1.12), (0.28, -1.20), (0.13, -1.24), (0.10, -1.34)]
    pts = [(x0 + px * s, y0 + py * s) for px, py in half] + [(x0 - px * s, y0 + py * s) for px, py in reversed(half)]
    d.polygon(pts, fill=c)
    # rounded shoulders
    d.ellipse([x0 - 0.50 * s, y0 - 1.28 * s, x0 + 0.50 * s, y0 - 0.98 * s], fill=c)
    # head
    d.ellipse([x0 - 0.20 * s, y0 - 1.74 * s, x0 + 0.20 * s, y0 - 1.28 * s], fill=c)
    over = over.resize(pil.size, Image.LANCZOS)
    if rim:
        rc = tuple(int(v) for v in hexc(rim))
        glowl = over.split()[3].filter(ImageFilter.GaussianBlur(14))
        g = Image.new('RGBA', pil.size, rc + (0,)); g.putalpha(glowl.point(lambda v: int(v * 0.7)))
        pil = Image.alpha_composite(pil, g)
    pil = Image.alpha_composite(pil, over)
    return np.asarray(pil.convert('RGB')).astype(float)

def save(img, name):
    img = grain(img, 3)
    Image.fromarray(np.clip(img, 0, 255).astype('uint8')).save(f'out/{name}.jpg', quality=88, optimize=True, progressive=True)
    print('saved', name)

# ---------------------------------------------------------------- scenes

def circles_01():
    img = vgrad([(0, '#070b1a'), (0.5, '#0f1c38'), (1, '#070b1a')])
    cx, cy = W / 2, H * 0.47
    img = glow(img, cx, cy, 520, '#3b6fb5', 0.9)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    for i, r in enumerate([120, 210, 300, 390, 480, 570]):
        w = 5 - i * 0.5
        a = np.exp(-((d - r) / w) ** 2) * (0.85 - i * 0.11)
        col = hexc('#a9c9ff') if i % 2 == 0 else hexc('#7fb2f0')
        img = img + a[..., None] * col * 0.9
    img = glow(img, cx, cy, 120, '#cfe0ff', 1.3)
    img = stars(img, 160, H, seed=11, bright=0.5)
    img = blur(img, 0.6)
    save(vignette(img, 0.45), 'calm_circles_01')

def circles_02():
    img = vgrad([(0, '#120b24'), (0.55, '#24164a'), (1, '#0c0818')])
    cx, cy = W / 2, H * 0.46
    img = glow(img, cx, cy, 480, '#7a4fd0', 0.8)
    yy, xx = np.mgrid[0:H, 0:W]
    dx, dy = xx - cx, yy - cy
    d = np.sqrt(dx ** 2 + dy ** 2); th = np.arctan2(dy, dx)
    # lotus / mandala petals: rings of rosettes
    for k, (r0, petals, col, a0) in enumerate([(150, 8, '#f5d0ff', 0.9), (260, 12, '#c9a6ff', 0.75), (380, 16, '#9f86ff', 0.6), (500, 24, '#7fb2f0', 0.45)]):
        rr = r0 * (1 + 0.12 * np.cos(petals * th))
        a = np.exp(-((d - rr) / 4.5) ** 2) * a0
        img = img + a[..., None] * hexc(col) * 0.85
    a = np.exp(-((d - 60) / 3) ** 2); img = img + a[..., None] * hexc('#fff0d6')
    img = glow(img, cx, cy, 90, '#ffe9c4', 1.4)
    img = stars(img, 120, H, seed=12, bright=0.45)
    img = blur(img, 0.6)
    save(vignette(img, 0.45), 'calm_circles_02')

def lake_01():
    hz = int(H * 0.56)
    img = vgrad([(0, '#0d1630'), (0.30, '#2a3a6a'), (0.47, '#d88f7c'), (0.56, '#f3c79a')])
    img = glow(img, W * 0.5, hz - 40, 260, '#ffd2a0', 0.9)
    img, _ = mountains(img, hz, 520, '#3a3e68', seed=21, rough=0.52, mist='#c98b8a', mist_h=120)
    img, _ = mountains(img, hz, 300, '#262a4c', seed=22, rough=0.6, mist='#8c6f86', mist_h=90)
    img, _ = mountains(img, hz, 140, '#161a32', seed=23, rough=0.65)
    img = reflect(img, hz, 0.75, '#141a33', seed=4)
    img = water_lines(img, hz + 10, H, '#ffd9b0', 160, seed=6, alpha=0.25)
    save(vignette(img, 0.35), 'calm_lake_01')

def lake_02():
    hz = int(H * 0.60)
    img = vgrad([(0, '#0a1222'), (0.35, '#1e3550'), (0.6, '#7a9bb0')])
    img = glow(img, W * 0.68, H * 0.22, 140, '#e8f2ff', 0.8)
    img = disc(img, W * 0.68, H * 0.22, 46, '#eef4ff', 2.5)
    img = stars(img, 260, H * 0.45, seed=31, bright=0.7)
    img, _ = mountains(img, hz, 420, '#2b4258', seed=32, rough=0.5, mist='#9fb6c6', mist_h=140)
    # pine tree line
    r = np.random.default_rng(33)
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8')); d = ImageDraw.Draw(pil)
    x = -20
    while x < W + 20:
        h = r.uniform(70, 170); w = h * 0.32
        d.polygon([(x, hz + 2), (x + w / 2, hz - h), (x + w, hz + 2)], fill=(14, 24, 34))
        x += r.uniform(14, 34)
    img = np.asarray(pil).astype(float)
    img = reflect(img, hz, 0.6, '#0b1520', seed=8)
    img = water_lines(img, hz + 8, H, '#cfe2f2', 120, seed=9, alpha=0.22)
    save(vignette(img, 0.35), 'calm_lake_02')

def waterfall_01():
    img = vgrad([(0, '#0e1a1c'), (0.4, '#1f3a3a'), (1, '#0c1616')])
    # cliffs left and right
    yy = np.arange(H)[:, None]; xx = np.arange(W)[None, :]
    left_edge = W * 0.36 + ridge(H, 0.6, 41) * 40
    right_edge = W * 0.64 + ridge(H, 0.6, 42) * 40
    rock = vgrad([(0, '#1b2b2a'), (1, '#0d1515')])
    mask = (xx < left_edge[:, None]) | (xx > right_edge[:, None])
    img = np.where(mask[..., None], rock, img)
    # foliage blobs on cliffs
    r = np.random.default_rng(43)
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8')); d = ImageDraw.Draw(pil, 'RGBA')
    for _ in range(2600):
        side = r.random() < 0.5
        x = r.uniform(0, W * 0.38) if side else r.uniform(W * 0.62, W)
        y = r.uniform(0, H * 0.82); rad = r.uniform(6, 26)
        g = r.integers(50, 120)
        d.ellipse([x - rad * 1.6, y - rad * 0.7, x + rad * 1.6, y + rad * 0.7], fill=(18, int(g), 52, 60))
    img = np.asarray(pil).astype(float)
    # falling water: vertical streak noise
    col = np.zeros((H, W))
    noise = r.random(W)
    noise = np.convolve(noise, np.ones(9) / 9, mode='same')
    streak = np.tile(noise[None, :], (H, 1))
    streak += r.normal(0, 0.06, (H, W)) * 0.5
    streak = np.asarray(Image.fromarray((np.clip(streak, 0, 1) * 255).astype('uint8')).filter(ImageFilter.GaussianBlur((1, 18)))).astype(float) / 255
    inside = (xx > left_edge[:, None] + 10) & (xx < right_edge[:, None] - 10) & (yy < H * 0.78)
    fall = np.clip(streak * 1.4 - 0.15, 0, 1) * inside
    img = img * (1 - fall[..., None] * 0.85) + hexc('#e6f4f2') * fall[..., None] * 0.85
    # mist at base and pool
    img = glow(img, W / 2, H * 0.78, 330, '#d9eeea', 1.2)
    pool_top = int(H * 0.8)
    img[pool_top:] = vgrad([(0, '#3e6a68'), (1, '#0d1c1c')], h=H - pool_top)
    img = water_lines(img, pool_top, H, '#cfeeea', 200, seed=44, alpha=0.3, maxlen=180)
    img = glow(img, W / 2, pool_top, 260, '#e9f7f5', 0.7)
    save(vignette(blur(img, 0.8), 0.4), 'calm_waterfall_01')

def stream_01():
    img = vgrad([(0, '#cfe3c8'), (0.25, '#7fa67a'), (0.45, '#2f4d33'), (1, '#16261a')])
    # sun rays through forest
    yy, xx = np.mgrid[0:H, 0:W]
    for k in range(5):
        x0 = W * (0.2 + 0.15 * k)
        ray = np.exp(-((xx - (x0 + (yy) * 0.25)) / 40) ** 2) * np.clip(1 - yy / (H * 0.7), 0, 1)
        img = img + ray[..., None] * hexc('#fff3c8') * 0.25
    # tree trunks
    r = np.random.default_rng(51)
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8')); d = ImageDraw.Draw(pil, 'RGBA')
    for _ in range(18):
        x = r.uniform(0, W); w = r.uniform(18, 60); depth = r.uniform(0.3, 1)
        c = (int(20 + 40 * (1 - depth)), int(32 + 50 * (1 - depth)), int(24 + 30 * (1 - depth)), 255)
        d.rectangle([x, 0, x + w * depth, H * (0.5 + 0.1 * depth)], fill=c)
    # stream: curving band towards the viewer
    pts_l, pts_r = [], []
    for i in range(60):
        t = i / 59; y = H * 0.48 + t * H * 0.52
        cx = W * 0.5 + math.sin(t * 3.0 + 0.5) * W * 0.18 * (1 - t * 0.3)
        half = 20 + t * t * W * 0.45
        pts_l.append((cx - half, y)); pts_r.append((cx + half, y))
    d.polygon(pts_l + pts_r[::-1], fill=(92, 140, 150, 255))
    # stones
    for _ in range(70):
        t = r.uniform(0.05, 1); y = H * 0.48 + t * H * 0.52
        cx = W * 0.5 + math.sin(t * 3.0 + 0.5) * W * 0.18 * (1 - t * 0.3)
        half = 20 + t * t * W * 0.45
        x = cx + r.choice([-1, 1]) * half * r.uniform(0.85, 1.15)
        rad = 6 + t * 50 * r.uniform(0.5, 1)
        g = int(r.uniform(60, 110))
        d.ellipse([x - rad * 1.4, y - rad * 0.8, x + rad * 1.4, y + rad * 0.8], fill=(g, g + 6, g, 255))
    img = np.asarray(pil).astype(float)
    img = water_lines(img, H * 0.5, H, '#e8fbff', 260, seed=52, alpha=0.4, maxlen=120)
    img = glow(img, W * 0.5, H * 0.5, 200, '#f6ffe0', 0.5)
    save(vignette(blur(img, 0.9), 0.4), 'calm_stream_01')

def water_01():
    hz = int(H * 0.42)
    img = vgrad([(0, '#141c3a'), (0.25, '#3c4f86'), (0.42, '#e3a6a0')])
    img = glow(img, W * 0.5, hz, 300, '#ffd1b5', 0.8)
    sea = vgrad([(0, '#5a6c9c'), (1, '#0d1430')], h=H - hz)
    img[hz:] = sea
    img = water_lines(img, hz + 2, H, '#ffe0cc', 420, seed=61, alpha=0.35, maxlen=320)
    img = glow(img, W * 0.5, hz + 220, 140, '#ffd7c0', 0.35)
    save(vignette(blur(img, 0.6), 0.35), 'calm_water_01')

def mountains_01():
    img = vgrad([(0, '#f2d6c4'), (0.35, '#c7b8d6'), (0.6, '#7d86b8'), (1, '#2b2f55')])
    img = glow(img, W * 0.3, H * 0.28, 220, '#fff0dc', 1.0)
    layers = [(0.48, 260, '#a99fc8', '#e8d6e4'), (0.58, 300, '#8a84b6', '#cfc0dc'), (0.68, 320, '#6a6a9e', '#b0a6cc'),
              (0.80, 340, '#4a4c7e', '#8d88b4'), (0.93, 360, '#2c2e56', None)]
    for i, (by, hgt, col, mist) in enumerate(layers):
        img, _ = mountains(img, int(H * by), hgt, col, seed=70 + i, rough=0.55, mist=mist, mist_h=120)
        img[int(H * by):] = img[int(H * by):] * 0 + hexc(col)
    save(vignette(blur(img, 0.5), 0.3), 'calm_mountains_01')

def monk_01():
    # monk on a ledge above a sea of clouds at sunrise
    img = vgrad([(0, '#1d2350'), (0.35, '#5a4f8a'), (0.55, '#f0a77c'), (0.62, '#ffd59a')])
    img = glow(img, W * 0.5, H * 0.6, 300, '#ffe0a8', 1.1)
    img, _ = mountains(img, int(H * 0.62), 380, '#6c5a8a', seed=81, rough=0.5, mist='#f6c3a0', mist_h=120)
    # clouds
    r = np.random.default_rng(82)
    pil = Image.fromarray(np.clip(img, 0, 255).astype('uint8')).convert('RGBA'); over = Image.new('RGBA', pil.size); d = ImageDraw.Draw(over)
    for _ in range(140):
        x = r.uniform(-100, W + 100); y = r.uniform(H * 0.6, H * 0.78); rx = r.uniform(80, 220); ry = rx * 0.35
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(255, 225, 205, 70))
    pil = Image.alpha_composite(pil, over.filter(ImageFilter.GaussianBlur(14)))
    img = np.asarray(pil.convert('RGB')).astype(float)
    # rocky ledge in foreground
    xx = np.arange(W)
    ledge = H * 0.80 - np.clip(1 - np.abs(xx - W * 0.42) / (W * 0.55), 0, 1) ** 0.6 * 120 + ridge(W, 0.6, 83) * 18
    yy = np.arange(H)[:, None]
    m = yy > ledge[None, :]
    img = np.where(m[..., None], vgrad([(0, '#241b2e'), (1, '#0d0a12')]), img)
    img = monk(img, W * 0.42, int(ledge[int(W * 0.42)]) + 6, 200, '#120d18', rim='#ffc98a')
    save(vignette(img, 0.35), 'calm_monk_01')

def monk_02():
    # monk by a moonlit lake
    hz = int(H * 0.58)
    img = vgrad([(0, '#060a18'), (0.4, '#13224a'), (0.58, '#3b5a86')])
    img = stars(img, 380, H * 0.5, seed=91, bright=0.8)
    img = glow(img, W * 0.5, H * 0.24, 200, '#cfe0ff', 0.9)
    img = disc(img, W * 0.5, H * 0.24, 70, '#f1f5ff', 2.5)
    img, _ = mountains(img, hz, 360, '#1a2a48', seed=92, rough=0.52, mist='#4a6690', mist_h=120)
    img = reflect(img, hz, 0.6, '#070d1c', seed=93)
    img = water_lines(img, hz + 8, H, '#dbe8ff', 150, seed=94, alpha=0.3)
    # shore in foreground
    xx = np.arange(W); yy = np.arange(H)[:, None]
    shore = H * 0.84 + ridge(W, 0.6, 95) * 22
    img = np.where((yy > shore[None, :])[..., None], vgrad([(0, '#0b111e'), (1, '#04060c')]), img)
    img = monk(img, W * 0.5, int(shore[int(W * 0.5)]) + 6, 175, '#05070d', rim='#9fb8ff')
    save(vignette(img, 0.35), 'calm_monk_02')

def monk_03():
    # three monks on a high plateau, layered misty peaks at dawn
    img = vgrad([(0, '#2a2f5e'), (0.3, '#8a7fb4'), (0.5, '#f2c6a8'), (0.62, '#f7dcc0')])
    img = glow(img, W * 0.62, H * 0.5, 240, '#fff1d8', 1.0)
    for i, (by, hgt, col, mist) in enumerate([(0.56, 300, '#b3a3c6', '#f0d8d4'), (0.64, 260, '#8f84b0', '#d8c4d4'), (0.72, 220, '#6a6694', '#b6a8c8')]):
        img, _ = mountains(img, int(H * by), hgt, col, seed=100 + i, rough=0.55, mist=mist, mist_h=110)
        img[int(H * by):] = hexc(col)
    xx = np.arange(W); yy = np.arange(H)[:, None]
    plateau = H * 0.80 + ridge(W, 0.6, 104) * 14
    img = np.where((yy > plateau[None, :])[..., None], vgrad([(0, '#2a2440'), (1, '#0e0b16')]), img)
    for x, sc in [(0.28, 120), (0.50, 135), (0.72, 120)]:
        img = monk(img, W * x, int(plateau[int(W * x)]) + 5, sc, '#16121f', rim='#ffd9b0')
    save(vignette(img, 0.3), 'calm_monk_03')

scenes = {f.__name__: f for f in [circles_01, circles_02, lake_01, lake_02, waterfall_01, stream_01, water_01, mountains_01, monk_01, monk_02, monk_03]}
if __name__ == '__main__':
    import os; os.makedirs('out', exist_ok=True)
    names = sys.argv[1:] or list(scenes)
    for n in names: scenes[n]()
