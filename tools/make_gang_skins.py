"""Compile painted gang UV sheets to VTF, retaining shipped dimensions and flags.

Run: python tools/make_gang_skins.py
Needs: pip install srctools pillow
Edit tools/gang_skins/<gang>/<class>_<sex>.png, then run this compiler.
"""
from pathlib import Path
from PIL import Image
from srctools.vtf import VTF, ImageFormats

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'materials/background_npcs/gangs'
SOURCE = ROOT / 'tools/gang_skins'


def main():
    # Validate every input before replacing any runtime textures.
    sheets = []
    for gang in ('crows', 'wolves'):
        for cls in ('light', 'heavy'):
            for sex in ('male', 'female'):
                name = f'{cls}_{sex}'
                target = OUT / gang / f'{name}.vtf'
                with target.open('rb') as file:
                    old = VTF.read(file)
                with Image.open(SOURCE / gang / f'{name}.png') as image:
                    if image.size != (old.width, old.height):
                        raise ValueError(f'{gang}/{name}: expected {old.width}x{old.height}, got {image.size}')
                    sheets.append((target, old, image.convert('RGBA')))
    for target, old, image in sheets:
        texture = VTF(old.width, old.height, version=(7, 2), fmt=ImageFormats.DXT1, flags=old.flags)
        texture.get().copy_from(image.tobytes(), ImageFormats.RGBA8888)
        texture.clear_mipmaps()
        texture.compute_mipmaps()
        with target.open('wb') as file:
            texture.save(file)
        print('wrote', target.relative_to(ROOT))


if __name__ == '__main__':
    main()
