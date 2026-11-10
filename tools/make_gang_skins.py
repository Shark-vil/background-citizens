"""Makes the gang reskins of the HL2 citizen (pistol members) and rebel (heavy members) clothing sheets.

Reads materials/models/humans/<sex>/<group>/citizen_sheet from the game's VPKs, recolors the clothes (skin tones
are kept) and writes new VTF/VMT files to materials/background_npcs/gangs/<gang>/<class>_<sex>.vtf|vmt,
which systems/npcs/sv_gang_models.lua puts on the actors with SetSubMaterial. The game's files are not copied
into the addon, only the recolored result.

Run:  python tools/make_gang_skins.py [--game D:/SteamLibrary/steamapps/common/GarrysMod]
Needs:  pip install vpk srctools pillow numpy
"""
from pathlib import Path
import argparse, io
import numpy as np
import vpk
from PIL import Image
from srctools.vtf import VTF, ImageFormats

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'materials/background_npcs/gangs'
# gang -> (hue in degrees, saturation factor, saturation floor, value factor)
GANGS = {
    'crows': (255, 0.55, 0.18, 0.85),   # charcoal with a cold violet cast
    'wolves': (358, 1.10, 0.85, 0.80),  # crimson
}
# class -> source group: citizen clothes for the pistol members, rebel gear for the heavy ones
CLASSES = {'light': 'group01', 'heavy': 'group03'}
SEXES = ('male', 'female')


def read_vpk_file(game, vpk_name, path):
    return vpk.open(str(game / 'sourceengine' / vpk_name)).get_file(path).read()


def recolor(img, hue, sat_mul, sat_floor, val_mul):
    rgba = np.asarray(img.convert('RGBA'), dtype=np.float32) / 255.0
    rgb = rgba[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    delta = mx - mn
    # hue of the source pixel, to tell skin (orange-pink, warm) from cloth
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.zeros_like(mx)
    nz = delta > 1e-6
    h = np.where(nz & (mx == r), ((g - b) / np.where(nz, delta, 1)) % 6, h)
    h = np.where(nz & (mx == g), (b - r) / np.where(nz, delta, 1) + 2, h)
    h = np.where(nz & (mx == b), (r - g) / np.where(nz, delta, 1) + 4, h)
    h = h * 60.0
    s = np.where(mx > 0, delta / np.where(mx > 0, mx, 1), 0)
    skin = ((h < 40) | (h > 340)) & (s > 0.22) & (mx > 0.25) & (r > g)
    # cloth: keep its light and dark detail, replace the color
    v = np.clip(mx ** 0.8 * val_mul, 0, 1)  # the gamma lifts the dark cloth
    new_s = np.clip(np.maximum(s * sat_mul, sat_floor * (mx > 0.04)), 0, 1)
    # vectorized hsv -> rgb at the gang's hue
    H = np.full(v.shape, hue / 360.0) * 6.0
    i = np.floor(H).astype(int) % 6
    f = H - np.floor(H)
    p = v * (1 - new_s); q = v * (1 - new_s * f); t = v * (1 - new_s * (1 - f))
    choices = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]
    out = np.stack([np.choose(i, [c[k] for c in choices]) for k in range(3)], -1)
    res = np.where(skin[..., None], rgb, out)
    result = np.concatenate([res, rgba[..., 3:]], -1)
    return Image.fromarray((np.clip(result, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--game', default='D:/SteamLibrary/steamapps/common/GarrysMod')
    game = Path(ap.parse_args().game)
    for sex in SEXES:
        for cls, group in CLASSES.items():
            path = f'materials/models/humans/{sex}/{group}/citizen_sheet.vtf'
            src = VTF.read(io.BytesIO(read_vpk_file(game, 'hl2_textures_dir.vpk', path)))
            img = src.get().to_PIL()
            for gang, params in GANGS.items():
                out_dir = OUT / gang
                out_dir.mkdir(parents=True, exist_ok=True)
                new = recolor(img, *params)
                vtf = VTF(src.width, src.height, version=(7, 2), fmt=ImageFormats.DXT1, flags=src.flags)
                vtf.get().copy_from(new.tobytes(), ImageFormats.RGBA8888)
                vtf.clear_mipmaps()
                vtf.compute_mipmaps()
                with open(out_dir / f'{cls}_{sex}.vtf', 'wb') as f:
                    vtf.save(f)
                (out_dir / f'{cls}_{sex}.vmt').write_text(
                    '"VertexLitGeneric"\n{\n\t"$basetexture" "background_npcs/gangs/%s/%s_%s"\n\t"$halflambert" 1\n}\n'
                    % (gang, cls, sex), encoding='ascii')
                print('wrote', out_dir / f'{cls}_{sex}.vtf')


if __name__ == '__main__':
    main()
