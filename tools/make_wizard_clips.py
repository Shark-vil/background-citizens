"""Builds the setup wizard clips: a folder of frames -> one 2048x2048 JPG atlas (5 columns of 384x216 frames).

Usage: python tools/make_wizard_clips.py <addon root> <clip name> <frames dir> [<frames dir> ...]
Every folder gives an equal share of the 45 frames (two folders: "before" then "after"), sampled evenly.
The first 2 frames of each folder are dropped (the first frames of a recording are smeared by the engine).
The frames (jpg/png/tga, any size 16:9) are read in name order.
The layout must match the constants of lua/background_npcs_core/ui/menu/cl_menu_wizard.lua.
"""
import sys
from pathlib import Path

from PIL import Image

ATLAS, FRAME_W, FRAME_H, COLS = 2048, 384, 216, 5

root, name, dirs = Path(sys.argv[1]), sys.argv[2], [Path(d) for d in sys.argv[3:]]
count = 45
assert count <= COLS * (ATLAS // FRAME_H), 'too many frames for the atlas'

shares = [count // len(dirs) + (1 if i < count % len(dirs) else 0) for i in range(len(dirs))]
sources = []
for frames_dir, share in zip(dirs, shares):
    files = sorted(p for p in frames_dir.iterdir() if p.suffix.lower() in ('.jpg', '.jpeg', '.png', '.tga'))[2:]
    assert len(files) >= 2, 'no frames in ' + str(frames_dir)
    sources += [files[round(i * (len(files) - 1) / max(share - 1, 1))] for i in range(share)]

atlas = Image.new('RGB', (ATLAS, ATLAS), (0, 0, 0))
for i, src in enumerate(sources):
    frame = Image.open(src).convert('RGB').resize((FRAME_W, FRAME_H), Image.LANCZOS)
    atlas.paste(frame, ((i % COLS) * FRAME_W, (i // COLS) * FRAME_H))

out = root / 'materials' / 'background_npcs' / 'wizard' / (name + '.jpg')
out.parent.mkdir(parents=True, exist_ok=True)
atlas.save(out, quality=84, optimize=True)
print(out, out.stat().st_size // 1024, 'KB', count, 'frames')
