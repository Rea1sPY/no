#!/usr/bin/env python3
"""ساخت بسته‌ی بافت بازی: بتن، کاشی، سقف، فلز، زنگ، چوب، کاغذ و لکه‌ی خون.

همه‌ی بافت‌ها رویه‌ای و کاشی‌شو (tileable) هستند. خروجی در پوشه‌ی textures/ است.
اجرا:  python3 tools/make_textures.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "textures")
os.makedirs(OUT, exist_ok=True)

S2 = 2048
S1 = 1024


def fbm(size, cells, octaves, seed, gain=0.5, lac=2.0):
    rng = np.random.default_rng(seed)
    total = np.zeros((size, size), np.float32)
    amp = 1.0
    norm = 0.0
    for o in range(octaves):
        c = max(2, int(round(cells * (lac ** o))))
        g = rng.random((c + 1, c + 1)).astype(np.float32)
        g[-1, :] = g[0, :]
        g[:, -1] = g[:, 0]
        im = Image.fromarray((g * 255.0).astype(np.uint8), "L").resize((size + 1, size + 1), Image.BICUBIC)
        total += (np.asarray(im, dtype=np.float32)[:size, :size] / 255.0) * amp
        norm += amp
        amp *= gain
    return total / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / max(1e-6, (e1 - e0)), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def crack_mask(size, seed, n=26, steps=700, blur=1.1, width=2):
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)
    for _ in range(n):
        x = float(rng.uniform(0, size))
        y = float(rng.uniform(0, size))
        ang = float(rng.uniform(0, math.tau))
        for _ in range(int(rng.integers(steps // 2, steps))):
            ang += float(rng.normal(0.0, 0.11))
            nx = x + math.cos(ang) * 1.6
            ny = y + math.sin(ang) * 1.6
            d.line([(x % size, y % size), (nx % size, ny % size)],
                   fill=int(rng.integers(160, 255)), width=int(rng.integers(1, width + 1)))
            x, y = nx % size, ny % size
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(img, dtype=np.float32) / 255.0


def normal_map(height, strength=2.2, size_hint=None):
    dx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    dy = np.roll(height, 1, axis=0) - np.roll(height, -1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    out = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)
    return (np.clip(out, 0.0, 1.0) * 255.0).astype(np.uint8)


def save(name, rgb, normal=None, height=None, strength=2.2):
    img = Image.fromarray((np.clip(rgb, 0.0, 1.0) * 255.0).astype(np.uint8), "RGB")
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=False, compress_level=6)
    print("%-24s %6.1f MB" % (name + ".png", os.path.getsize(path) / 1048576.0))
    if height is not None:
        n = normal_map(height, strength)
        nimg = Image.fromarray(n, "RGB")
        npath = os.path.join(OUT, name + "_n.png")
        nimg.save(npath, optimize=False, compress_level=6)
        print("%-24s %6.1f MB" % (name + "_n.png", os.path.getsize(npath) / 1048576.0))


def colorize(h, col_a, col_b, grime=None):
    hh = np.clip(h, 0.0, 1.0)[..., None]
    c = np.asarray(col_a, np.float32)[None, None, :] * (1.0 - hh) + \
        np.asarray(col_b, np.float32)[None, None, :] * hh
    if grime is not None:
        c = c * (1.0 - np.clip(grime, 0.0, 1.0)[..., None] * 0.75)
    return c


# ---------------------------------------------------------------- بتن دیوار
def concrete_wall():
    size = S2
    base = fbm(size, 6, 7, 11)
    grain = fbm(size, 220, 3, 12)
    patch = fbm(size, 20, 4, 13)
    crack = crack_mask(size, 14, n=30, steps=900, blur=1.2)
    chipped = smooth(0.62, 0.78, fbm(size, 40, 4, 15)) * smooth(0.55, 0.8, patch)
    h = 0.55 * base + 0.30 * grain + 0.15 * patch - crack * 0.55
    h = np.clip(h, 0.0, 1.0)
    stain = smooth(0.48, 0.82, fbm(size, 4, 6, 16))
    crease = smooth(0.52, 0.7, fbm(size, 12, 4, 17))
    col = colorize(h, (0.26, 0.255, 0.275), (0.47, 0.46, 0.485), stain * 0.5)
    # نم و لکه‌های سبز-قهوه‌ای
    col[:, :, 1] *= 1.0 - stain * 0.10
    col[:, :, 0] *= 1.0 + stain * 0.06
    col *= (1.0 - crack[..., None] * 0.55)
    col *= (1.0 - chipped[..., None] * 0.45)
    col *= (0.86 + 0.24 * grain[..., None])
    col += crease[..., None] * 0.02
    save("concrete_wall", col, height=h, strength=2.4)


# ---------------------------------------------------------------- کف کاشی
def tile_floor():
    size = S2
    n = 4
    cell = size // n
    grout = 6
    yy, xx = np.mgrid[0:size, 0:size]
    ti = xx // cell
    tj = yy // cell
    lx = xx % cell
    ly = yy % cell
    edge = np.minimum(np.minimum(lx, cell - 1 - lx), np.minimum(ly, cell - 1 - ly))
    grout_mask = smooth(grout, grout + 3.0, edge.astype(np.float32))
    rng = np.random.default_rng(21)
    tile_tone = rng.uniform(0.78, 1.12, (n, n)).astype(np.float32)
    tone = tile_tone[tj, ti]
    dirt = fbm(size, 32, 5, 22)
    fine = fbm(size, 260, 3, 23)
    smudge = fbm(size, 8, 4, 24)
    cracks = crack_mask(size, 25, n=16, steps=520, blur=0.9)
    h = (0.85 * grout_mask) - cracks * 0.5
    h += 0.05 * fine
    h = np.clip(h, 0.0, 1.0)
    base = np.stack([
        0.30 + 0.18 * tone + 0.05 * dirt,
        0.285 + 0.17 * tone + 0.05 * dirt,
        0.26 + 0.15 * tone + 0.05 * dirt,
    ], axis=-1)
    base *= (0.86 + 0.28 * fine[..., None])
    base *= (1.0 - smooth(0.55, 0.9, smudge)[..., None] * 0.28)
    base *= (0.42 + 0.58 * grout_mask[..., None])
    base *= (1.0 - cracks[..., None] * 0.35)
    base += np.stack([dirt * 0.05, dirt * 0.04, dirt * 0.03], axis=-1)
    save("tile_floor", base, height=h, strength=2.9)


# ---------------------------------------------------------------- سقف
def ceiling_panel():
    size = size_c = 2048
    n = 4
    cell = size // n
    yy, xx = np.mgrid[0:size, 0:size]
    lx = xx % cell
    ly = yy % cell
    edge = np.minimum(np.minimum(lx, cell - 1 - lx), np.minimum(ly, cell - 1 - ly))
    seam = smooth(3.0, 8.0, edge.astype(np.float32))
    holes = fbm(size, 90, 4, 31)
    stain = smooth(0.5, 0.85, fbm(size, 5, 6, 32))
    flake = smooth(0.62, 0.78, fbm(size, 28, 4, 33))
    h = seam * 0.9 + holes * 0.1 - flake * 0.25
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.30 + 0.10 * holes,
        0.29 + 0.10 * holes,
        0.275 + 0.09 * holes,
    ], axis=-1)
    col *= (0.5 + 0.5 * seam[..., None])
    col *= (1.0 - stain[..., None] * 0.35)
    col += np.stack([stain * 0.10, stain * 0.075, stain * 0.03], axis=-1)
    col *= (1.0 - flake[..., None] * 0.35)
    save("ceiling_panel", col, height=h, strength=2.0)


# ---------------------------------------------------------------- بتن زنگ‌زده
def concrete_wall_b():
    size = S2
    base = fbm(size, 8, 7, 111)
    grain = fbm(size, 240, 3, 112)
    mold = smooth(0.52, 0.82, fbm(size, 6, 6, 113))
    crack = crack_mask(size, 114, n=38, steps=1000, blur=1.3)
    h = 0.55 * base + 0.45 * grain - crack * 0.6
    h = np.clip(h, 0.0, 1.0)
    col = colorize(h, (0.20, 0.22, 0.18), (0.36, 0.38, 0.32), mold * 0.6)
    col *= (1.0 - crack[..., None] * 0.6)
    col *= (0.88 + 0.24 * grain[..., None])
    save("concrete_wall_b", col, height=h, strength=2.6)


# ---------------------------------------------------------------- کاشی قهوه‌ای
def tile_floor_b():
    size = S2
    n = 8
    cell = size // n
    grout = 5
    yy, xx = np.mgrid[0:size, 0:size]
    ti = xx // cell
    tj = yy // cell
    lx = xx % cell
    ly = yy % cell
    edge = np.minimum(np.minimum(lx, cell - 1 - lx), np.minimum(ly, cell - 1 - ly))
    grout_mask = smooth(grout, grout + 3.0, edge.astype(np.float32))
    rng = np.random.default_rng(211)
    tone = rng.uniform(0.75, 1.15, (n, n)).astype(np.float32)[tj, ti]
    dirt = fbm(size, 34, 5, 212)
    fine = fbm(size, 280, 3, 213)
    crack = crack_mask(size, 214, n=20, steps=560, blur=0.9)
    h = 0.85 * grout_mask - crack * 0.45 + 0.05 * fine
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.24 + 0.15 * tone + 0.05 * dirt,
        0.19 + 0.11 * tone + 0.04 * dirt,
        0.15 + 0.08 * tone + 0.03 * dirt,
    ], axis=-1)
    col *= (0.85 + 0.3 * fine[..., None])
    col *= (0.42 + 0.58 * grout_mask[..., None])
    col *= (1.0 - crack[..., None] * 0.4)
    save("tile_floor_b", col, height=h, strength=2.8)


# ---------------------------------------------------------------- فلز
def metal_panel():
    size = S1
    base = fbm(size, 4, 5, 41)
    fine = fbm(size, 300, 2, 42)
    brush = fbm(size, 1024, 1, 43)
    yy, xx = np.mgrid[0:size, 0:size]
    seam_x = np.abs(((xx + size // 2) % (size // 2)) - size // 4).astype(np.float32)
    seam = smooth(2.0, 5.0, seam_x)
    rivets = np.zeros((size, size), np.float32)
    for cy in range(0, size, 256):
        for cx in range(0, size, 256):
            px = (xx - (cx + 64)) ** 2 + (yy - (cy + 64)) ** 2
            px2 = (xx - (cx + 192)) ** 2 + (yy - (cy + 192)) ** 2
            rivets += np.exp(-px / 90.0) + np.exp(-px2 / 90.0)
    rivets = np.clip(rivets, 0.0, 1.0)
    scratch = crack_mask(size, 44, n=70, steps=190, blur=0.6)
    h = 0.4 * base + 0.2 * fine + 0.5 * seam + rivets * 0.8 - scratch * 0.25
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.36 + 0.10 * base + 0.05 * brush,
        0.37 + 0.10 * base + 0.05 * brush,
        0.39 + 0.10 * base + 0.05 * brush,
    ], axis=-1)
    col *= (0.55 + 0.45 * seam[..., None])
    col += rivets[..., None] * 0.10
    col *= (1.0 - scratch[..., None] * 0.3)
    col *= (0.88 + 0.22 * fine[..., None])
    save("metal_panel", col, height=h, strength=1.7)


# ---------------------------------------------------------------- درِ فلزی
def metal_door():
    size = S2
    base = fbm(size, 5, 5, 121)
    grain = fbm(size, 300, 2, 122)
    scratch = crack_mask(size, 123, n=60, steps=240, blur=0.7)
    yy, xx = np.mgrid[0:size, 0:size]
    plate = smooth(2.0, 6.0, np.minimum(np.minimum(xx, size - 1 - xx), np.minimum(yy, size - 1 - yy)).astype(np.float32))
    rivets = np.zeros((size, size), np.float32)
    for cy in range(0, size, 256):
        for cx in range(0, size, 256):
            px = (xx - cx) ** 2 + (yy - cy) ** 2
            rivets += np.exp(-px / 80.0)
    rivets = np.clip(rivets, 0.0, 1.0)
    stripe = np.where((np.floor((xx + yy) / 42.0) % 2) == 0, 1.0, 0.0)
    stripe_band = (yy > size - 170).astype(np.float32) * (yy < size - 60).astype(np.float32)
    h = 0.5 * base + 0.2 * grain + 0.5 * plate + rivets * 0.7 - scratch * 0.3
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.30 + 0.12 * base + 0.05 * grain,
        0.31 + 0.12 * base + 0.05 * grain,
        0.33 + 0.12 * base + 0.05 * grain,
    ], axis=-1)
    col *= (0.6 + 0.4 * plate[..., None])
    col += rivets[..., None] * 0.08
    col *= (1.0 - scratch[..., None] * 0.3)
    col = col * (1.0 - stripe_band[..., None] * 0.9) + \
        np.stack([0.62 * stripe, 0.50 * stripe, 0.05 * stripe], axis=-1) * stripe_band[..., None]
    save("metal_door", col, height=h, strength=2.3)


# ---------------------------------------------------------------- نوار خطر
def hazard_stripes():
    size = S1
    yy, xx = np.mgrid[0:size, 0:size]
    band = np.floor((xx + yy) / 64.0) % 2
    base = np.where(band == 0, 0.72, 0.10)
    grain = fbm(size, 180, 3, 131)
    wear = smooth(0.5, 0.85, fbm(size, 9, 5, 132))
    col = np.stack([base, base * 0.82, base * 0.10], axis=-1)
    col *= (0.8 + 0.4 * grain[..., None])
    col *= (1.0 - wear[..., None] * 0.45)
    save("hazard_stripes", col, height=grain, strength=0.8)


# ---------------------------------------------------------------- دریچه
def vent_grate():
    size = S1
    yy, xx = np.mgrid[0:size, 0:size]
    slat = np.where((yy // 40) % 2 == 0, 0.62, 0.16)
    frame = smooth(4.0, 10.0, np.minimum(np.minimum(xx, size - 1 - xx), np.minimum(yy, size - 1 - yy)).astype(np.float32))
    grain = fbm(size, 160, 3, 141)
    col = np.stack([slat * 0.55, slat * 0.56, slat * 0.58], axis=-1)
    col *= (0.35 + 0.65 * frame[..., None])
    col *= (0.85 + 0.3 * grain[..., None])
    save("vent_grate", col, height=slat * frame, strength=1.5)


# ---------------------------------------------------------------- زنگ
def rust_metal():
    size = S1
    m = fbm(size, 5, 7, 51)
    spot = smooth(0.45, 0.8, fbm(size, 26, 5, 52))
    pit = smooth(0.72, 0.86, fbm(size, 140, 3, 53))
    h = 0.6 * m + 0.4 * spot - pit * 0.6
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.30 + 0.30 * m + 0.18 * spot,
        0.15 + 0.17 * m + 0.10 * spot,
        0.06 + 0.08 * m + 0.04 * spot,
    ], axis=-1)
    col *= (1.0 - pit[..., None] * 0.65)
    col *= (0.85 + 0.3 * spot[..., None])
    save("rust_metal", col, height=h, strength=2.8)


# ---------------------------------------------------------------- چوب
def wood_planks():
    size = S1
    n = 4
    cell = size // n
    yy, xx = np.mgrid[0:size, 0:size]
    plank = (xx // cell).astype(np.int32)
    rng = np.random.default_rng(61)
    tone = rng.uniform(0.82, 1.12, n).astype(np.float32)[plank]
    grain = np.sin((yy.astype(np.float32) * 0.05) + fbm(size, 30, 5, 62) * 9.0) * 0.5 + 0.5
    fine = fbm(size, 300, 3, 63)
    gap = smooth(1.0, 4.0, np.abs(((xx + cell // 2) % cell) - cell // 2).astype(np.float32))
    knot = smooth(0.82, 0.95, fbm(size, 60, 4, 64))
    h = 0.5 * grain + 0.3 * fine + gap * 0.4 - knot * 0.3
    h = np.clip(h, 0.0, 1.0)
    col = np.stack([
        0.24 + 0.14 * grain + 0.05 * fine,
        0.16 + 0.10 * grain + 0.04 * fine,
        0.09 + 0.06 * grain + 0.03 * fine,
    ], axis=-1)
    col *= (0.72 + 0.28 * tone[..., None])
    col *= (0.45 + 0.55 * gap[..., None])
    col *= (1.0 - knot[..., None] * 0.5)
    save("wood_planks", col, height=h, strength=2.2)


# ---------------------------------------------------------------- کاغذ
def paper_old():
    size = S1
    fiber = fbm(size, 400, 2, 71)
    stain = smooth(0.55, 0.9, fbm(size, 6, 6, 72))
    edge = np.minimum(np.minimum(np.mgrid[0:size, 0:size][1], size - 1 - np.mgrid[0:size, 0:size][1]),
                      np.minimum(np.mgrid[0:size, 0:size][0], size - 1 - np.mgrid[0:size, 0:size][0]))
    burn = smooth(0.0, 60.0, edge.astype(np.float32))
    h = 0.3 * fiber + 0.7
    col = np.stack([
        0.74 + 0.10 * fiber,
        0.70 + 0.09 * fiber,
        0.58 + 0.08 * fiber,
    ], axis=-1)
    col *= (1.0 - stain[..., None] * 0.30)
    col += np.stack([stain * 0.08, stain * 0.06, stain * 0.02], axis=-1)
    col *= (0.55 + 0.45 * burn[..., None])
    save("paper_old", col, height=h, strength=0.6)


# ---------------------------------------------------------------- خون
def blood_decal():
    size = S1
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(81)
    cx, cy = size // 2, size // 2
    for _ in range(26):
        r = int(rng.integers(40, 210))
        ox = int(rng.normal(0, 150))
        oy = int(rng.normal(0, 150))
        d.ellipse([cx + ox - r, cy + oy - r * 0.7, cx + ox + r, cy + oy + r * 0.7],
                  fill=(int(rng.integers(80, 130)), 4, 6, int(rng.integers(150, 235))))
    for _ in range(22):
        x = cx + int(rng.normal(0, 190))
        y = cy + int(rng.normal(0, 150))
        h = int(rng.integers(30, 220))
        w = int(rng.integers(6, 22))
        d.ellipse([x - w // 2, y, x + w // 2, y + h], fill=(int(rng.integers(70, 120)), 3, 5, 220))
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(img, dtype=np.float32)
    noise = fbm(size, 90, 3, 82)
    a[:, :, 3] *= (0.55 + 0.45 * noise)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    path = os.path.join(OUT, "blood_decal.png")
    img.save(path, optimize=False, compress_level=6)
    print("%-24s %6.1f MB" % ("blood_decal.png", os.path.getsize(path) / 1048576.0))


# ---------------------------------------------------------------- پوستر
def poster_sheet(name, seed, tint):
    size = S1
    rng = np.random.default_rng(seed)
    paper = paper_old_array(size)
    img = Image.fromarray((np.clip(paper, 0, 1) * 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    # نوارهای هشدار
    d.rectangle([0, 0, size, 90], fill=(int(tint[0] * 255), int(tint[1] * 255), int(tint[2] * 255)))
    for i in range(0, size, 46):
        d.line([(i, 0), (i + 60, 90)], fill=(20, 18, 18), width=16)
    # کادر و نشان
    d.rectangle([44, 130, size - 44, size - 60], outline=(30, 26, 24), width=6)
    d.ellipse([size // 2 - 150, 230, size // 2 + 150, 530], outline=(40, 30, 28), width=10)
    d.line([(size // 2 - 110, 300), (size // 2 + 110, 460)], fill=(55, 20, 20), width=12)
    d.line([(size // 2 + 110, 300), (size // 2 - 110, 460)], fill=(55, 20, 20), width=12)
    for i in range(7):
        y = 620 + i * 46
        w = int(rng.integers(320, 700))
        d.rectangle([110, y, 110 + w, y + 12], fill=(48, 40, 38, 255))
    for _ in range(70):
        x = int(rng.integers(0, size))
        y = int(rng.integers(0, size))
        s = int(rng.integers(2, 12))
        d.ellipse([x, y, x + s, y + s], fill=(70, 55, 45))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=False, compress_level=6)
    print("%-24s %6.1f MB" % (name + ".png", os.path.getsize(path) / 1048576.0))


def poster_big(name, seed, tint, size):
    rng = np.random.default_rng(seed)
    paper = paper_old_array(size)
    img = Image.fromarray((np.clip(paper, 0, 1) * 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, size, size // 8], fill=(int(tint[0] * 255), int(tint[1] * 255), int(tint[2] * 255)))
    for i in range(0, size, 70):
        d.line([(i, 0), (i + 90, size // 8)], fill=(18, 16, 16), width=22)
    d.rectangle([70, 260, size - 70, size - 80], outline=(32, 28, 26), width=8)
    for i in range(9):
        y = 360 + i * 78
        w = int(rng.integers(500, 1100))
        d.rectangle([150, y, 150 + w, y + 18], fill=(46, 38, 36))
    for _ in range(120):
        x = int(rng.integers(0, size))
        y = int(rng.integers(0, size))
        s = int(rng.integers(3, 18))
        d.ellipse([x, y, x + s, y + s], fill=(66, 50, 42))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    path = os.path.join(OUT, name + ".png")
    img.save(path, optimize=False, compress_level=6)
    print("%-24s %6.1f MB" % (name + ".png", os.path.getsize(path) / 1048576.0))


def paper_old_array(size):
    fiber = fbm(size, 400, 2, 71)
    stain = smooth(0.55, 0.9, fbm(size, 6, 6, 72))
    col = np.stack([
        0.72 + 0.10 * fiber,
        0.68 + 0.09 * fiber,
        0.56 + 0.08 * fiber,
    ], axis=-1)
    col *= (1.0 - stain[..., None] * 0.28)
    return col


if __name__ == "__main__":
    print("generating textures ...")
    concrete_wall()
    tile_floor()
    ceiling_panel()
    metal_panel()
    rust_metal()
    wood_planks()
    paper_old()
    blood_decal()
    poster_sheet("poster_warning", 91, (0.62, 0.50, 0.10))
    poster_sheet("poster_notice", 92, (0.42, 0.10, 0.12))
    concrete_wall_b()
    tile_floor_b()
    metal_door()
    hazard_stripes()
    vent_grate()
    poster_big("poster_terminal", 93, (0.10, 0.55, 0.55), 2048)
    poster_big("poster_blood", 94, (0.45, 0.05, 0.07), 2048)
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("TOTAL %.1f MB" % (total / 1048576.0))
