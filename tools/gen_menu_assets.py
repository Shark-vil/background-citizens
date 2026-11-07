"""Generates the settings menu sounds (soft sine tones) and monochrome icons for Background NPCs.

Usage: python tools/gen_menu_assets.py .   (needs numpy and Pillow)
"""
import math
import sys
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(sys.argv[1])
RATE = 44100


# ---------------------------------------------------------------------------
# Sounds
# ---------------------------------------------------------------------------

def note(freq, dur, attack=0.004, tau=0.03, amp=0.2, harmonic=0.12, glide_to=None):
    t = np.arange(int(dur * RATE)) / RATE
    if glide_to:
        f = freq + (glide_to - freq) * (t / dur)
        phase = 2 * math.pi * np.cumsum(f) / RATE
    else:
        phase = 2 * math.pi * freq * t
    wave_ = np.sin(phase) + harmonic * np.sin(2 * phase)
    env = np.minimum(t / attack, 1.0) * np.exp(-t / tau)
    return wave_ * env * amp


def mix(parts, dur):
    out = np.zeros(int(dur * RATE))
    for offset, samples in parts:
        start = int(offset * RATE)
        end = min(len(out), start + len(samples))
        out[start:end] += samples[: end - start]
    return out


def soften(samples, cutoff=5000):
    # one-pole low-pass: takes the edge off the attack
    alpha = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out = np.empty_like(samples)
    acc = 0.0
    for i, x in enumerate(samples):
        acc += alpha * (x - acc)
        out[i] = acc
    fade = min(len(out), int(0.004 * RATE))
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def write(name, samples):
    path = ROOT / 'sound' / 'background_npcs' / 'ui' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(samples, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


SOUNDS = {
    'hover.wav': mix([(0, note(1760, 0.04, 0.002, 0.008, 0.07))], 0.05),
    'click.wav': mix([(0, note(1046, 0.09, 0.0015, 0.02, 0.22)), (0, note(1568, 0.09, 0.0015, 0.014, 0.07))], 0.1),
    'toggle_on.wav': mix([(0, note(784, 0.1, 0.002, 0.03, 0.18)), (0.045, note(1175, 0.12, 0.002, 0.035, 0.18))], 0.18),
    'toggle_off.wav': mix([(0, note(1175, 0.1, 0.002, 0.03, 0.15)), (0.045, note(784, 0.12, 0.002, 0.035, 0.17))], 0.18),
    'open.wav': mix([
        (0, note(523, 0.45, 0.018, 0.13, 0.12)),
        (0.03, note(659, 0.42, 0.018, 0.12, 0.11)),
        (0.06, note(784, 0.4, 0.018, 0.11, 0.1)),
    ], 0.48),
    'close.wav': mix([(0, note(880, 0.16, 0.004, 0.05, 0.16, glide_to=587))], 0.18),
    'tick.wav': mix([(0, note(2200, 0.02, 0.001, 0.004, 0.05))], 0.025),
    'denied.wav': mix([(0, note(196, 0.09, 0.004, 0.03, 0.3, 0.3)), (0.1, note(185, 0.1, 0.004, 0.035, 0.28, 0.3))], 0.22),
}


# ---------------------------------------------------------------------------
# Icons: white glyphs on transparent, drawn at 4x and scaled down
# ---------------------------------------------------------------------------

S = 256          # canvas
W = 255          # white
LINE = 20        # stroke width at canvas scale


def canvas():
    img = Image.new('L', (S, S), 0)
    return img, ImageDraw.Draw(img)


def rotate(points, angle, cx=S / 2, cy=S / 2):
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in points]


def icon_gear():
    img, d = canvas()
    for i in range(8):
        d.polygon(rotate([(112, 22), (144, 22), (148, 70), (108, 70)], i * math.pi / 4), fill=W)
    d.ellipse((48, 48, 208, 208), fill=W)
    d.ellipse((96, 96, 160, 160), fill=0)
    return img


def person(d, cx, top, scale):
    r = 34 * scale
    d.ellipse((cx - r, top, cx + r, top + 2 * r), fill=W)
    body_top = top + 2 * r + 12 * scale
    d.rounded_rectangle((cx - 62 * scale, body_top, cx + 62 * scale, body_top + 90 * scale), radius=46 * scale, fill=W)


def icon_actors():
    img, d = canvas()
    person(d, 168, 52, 0.8)
    # gap around the front person
    d.ellipse((40, 34, 160, 154), fill=0)
    d.rounded_rectangle((8, 140, 176, 260), radius=60, fill=0)
    person(d, 100, 44, 1.0)
    return img


def icon_pin():
    img, d = canvas()
    d.ellipse((58, 24, 198, 164), fill=W)
    d.polygon([(70, 120), (186, 120), (128, 236)], fill=W)
    d.ellipse((100, 66, 156, 122), fill=0)
    return img


def icon_star():
    img, d = canvas()
    pts = []
    for i in range(10):
        r = 112 if i % 2 == 0 else 48
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((128 + r * math.cos(a), 136 + r * math.sin(a)))
    d.polygon(pts, fill=W)
    return img


def icon_shield():
    img, d = canvas()
    d.polygon([(128, 18), (218, 52), (210, 140), (128, 238), (46, 140), (38, 52)], fill=W)
    d.polygon([(128, 50), (186, 72), (180, 134), (128, 198)], fill=0)
    return img


def icon_bubble():
    img, d = canvas()
    d.rounded_rectangle((24, 40, 232, 184), radius=48, fill=W)
    d.polygon([(64, 170), (120, 170), (56, 230)], fill=W)
    for x in (84, 128, 172):
        d.ellipse((x - 14, 98, x + 14, 126), fill=0)
    return img


def icon_graph():
    img, d = canvas()
    nodes = [(56, 196), (128, 70), (204, 176)]
    for a, b in ((0, 1), (1, 2), (0, 2)):
        d.line([nodes[a], nodes[b]], fill=W, width=LINE)
    for x, y in nodes:
        d.ellipse((x - 34, y - 34, x + 34, y + 34), fill=W)
    return img


def icon_gauge():
    img, d = canvas()
    d.arc((26, 40, 230, 244), 180, 360, fill=W, width=28)
    d.line([(128, 142), (186, 88)], fill=W, width=24)
    d.ellipse((104, 118, 152, 166), fill=W)
    d.rectangle((26, 190, 230, 210), fill=W)
    return img


def icon_grid():
    img, d = canvas()
    for x, y in ((30, 30), (140, 30), (30, 140), (140, 140)):
        d.rounded_rectangle((x, y, x + 86, y + 86), radius=22, fill=W)
    return img


def icon_monitor():
    img, d = canvas()
    d.rounded_rectangle((20, 36, 236, 180), radius=18, fill=W)
    d.rectangle((44, 58, 212, 156), fill=0)
    d.rectangle((110, 180, 146, 214), fill=W)
    d.rounded_rectangle((70, 206, 186, 228), radius=10, fill=W)
    return img


def icon_wrench():
    img, d = canvas()
    hx, hy = 170, 86  # head centre; the handle runs down-left from it
    d.line([(hx, hy), (60, 196)], fill=W, width=46)
    d.ellipse((60 - 23, 196 - 23, 60 + 23, 196 + 23), fill=W)
    d.ellipse((hx - 64, hy - 64, hx + 64, hy + 64), fill=W)
    # open jaw: a slot from the head centre outwards (up-right)
    d.polygon(rotate([(hx - 24, hy - 100), (hx + 24, hy - 100), (hx + 24, hy - 8), (hx - 24, hy - 8)], math.pi / 4, hx, hy), fill=0)
    return img


def icon_sun():
    img, d = canvas()
    d.ellipse((76, 76, 180, 180), fill=W)
    for i in range(8):
        d.polygon(rotate([(118, 8), (138, 8), (138, 50), (118, 50)], i * math.pi / 4), fill=W)
    return img


def icon_moon():
    img, d = canvas()
    d.ellipse((30, 30, 226, 226), fill=W)
    d.ellipse((92, 6, 262, 176), fill=0)
    return img


def icon_close():
    img, d = canvas()
    d.line([(52, 52), (204, 204)], fill=W, width=26)
    d.line([(204, 52), (52, 204)], fill=W, width=26)
    return img


def icon_lock():
    img, d = canvas()
    d.arc((66, 18, 190, 150), 180, 360, fill=W, width=26)
    d.rectangle((66, 80, 92, 118), fill=W)
    d.rectangle((164, 80, 190, 118), fill=W)
    d.rounded_rectangle((40, 110, 216, 238), radius=24, fill=W)
    d.ellipse((112, 148, 144, 180), fill=0)
    d.rectangle((122, 170, 134, 206), fill=0)
    return img


def save_mono(name, img, size=64):
    path = ROOT / 'materials' / 'background_npcs' / 'vgui' / 'menu' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    alpha = img.resize((size, size), Image.LANCZOS)
    rgba = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    rgba.putalpha(alpha)
    rgba.save(path)


def save_app_icon():
    # the context menu (C) icon: accent tile with the actors glyph
    size = 256
    tile = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((8, 8, 248, 248), radius=56, fill=(37, 99, 235, 255))
    glyph = icon_actors().resize((168, 168), Image.LANCZOS)
    white = Image.new('RGBA', glyph.size, (255, 255, 255, 255))
    tile.paste(white, (44, 50), glyph)
    path = ROOT / 'materials' / 'background_npcs' / 'vgui' / 'menu' / 'app.png'
    tile.resize((64, 64), Image.LANCZOS).save(path)


ICONS = {
    'general.png': icon_gear, 'actors.png': icon_actors, 'spawn.png': icon_pin, 'wanted.png': icon_star,
    'arrest.png': icon_shield, 'behavior.png': icon_bubble, 'navigation.png': icon_graph,
    'performance.png': icon_gauge, 'addons.png': icon_grid, 'client.png': icon_monitor, 'tools.png': icon_wrench,
    'sun.png': icon_sun, 'moon.png': icon_moon, 'close.png': icon_close, 'lock.png': icon_lock,
}

if __name__ == '__main__':
    for name, samples in SOUNDS.items():
        write(name, soften(samples))
    for name, draw in ICONS.items():
        save_mono(name, draw())
    save_app_icon()
    print('ok', len(SOUNDS), 'sounds', len(ICONS) + 1, 'icons')
