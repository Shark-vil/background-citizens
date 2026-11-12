"""Check all painted sheets and their compiled runtime textures."""
import unittest

from PIL import Image, ImageChops
from srctools.vtf import VTF, ImageFormats

from make_gang_skins import OUT, SOURCE


class GangSkinsTest(unittest.TestCase):
    def test_runtime_sheets(self):
        for gang in ('crows', 'wolves'):
            for cls, size in (('light', 1024), ('heavy', 2048)):
                for sex in ('male', 'female'):
                    name = f'{cls}_{sex}'
                    with self.subTest(gang=gang, sheet=name):
                        with Image.open(SOURCE / gang / f'{name}.png') as image:
                            self.assertEqual(image.size, (size, size))
                            with (OUT / gang / f'{name}.vtf').open('rb') as file:
                                texture = VTF.read(file)
                                decoded = texture.get().to_PIL().convert('RGB')
                            self.assertEqual((texture.width, texture.height), image.size)
                            self.assertEqual(texture.format, ImageFormats.DXT1)
                            self.assertEqual(texture.mipmap_count, size.bit_length() - 1)
                            # Compression may change colors, but must retain the painted image.
                            diff = ImageChops.difference(image.convert('RGB'), decoded)
                            histogram = diff.histogram()
                            error = sum((i % 256) * count for i, count in enumerate(histogram))
                            self.assertLess(error / (size * size * 3), 12)


if __name__ == '__main__':
    unittest.main()
