"""Build checks: python.exe -m unittest discover -s tools -p test_build.py -v"""
import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import build_addon


class BuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.minifier = build_addon.Minifier(build_addon.ROOT / 'build/.tools')

    def equivalent(self, source):
        from lupa.luajit21 import LuaRuntime
        source = source.encode('utf-8')
        result, cached = self.minifier.minify(source)
        self.assertNotIn(b'\n', result)
        self.assertNotIn(b'\r', result)
        original = LuaRuntime(encoding=None, unpack_returned_tuples=True).execute(source)
        compiled = LuaRuntime(encoding=None, unpack_returned_tuples=True).execute(result)
        self.assertEqual(original, compiled, result)
        return result, cached

    def test_scopes_and_globals(self):
        self.equivalent('a=10; local value=2; do local value=3; a=a+value end; return a+value')
        self.equivalent('local n=4; local function f(n) return function(v) return n+v end end; return f(n)(3)')
        self.equivalent('local object={}; local self=99; function object:read() return self.value end; object.value=4; return object:read(),self')
        self.equivalent('local count=0; repeat local done=count>2; count=count+1 until done; return count')
        self.equivalent('local total=0; for i=1,5 do if i==3 then goto skip end; total=total+i; ::skip:: end; return total')

    def test_literals_and_token_boundaries(self):
        self.equivalent('-- comment-only file')
        self.equivalent('return 1 .. "2", 3 - -4')
        self.equivalent('return [=[\nтекст\r\n"quote"\n]=], "123", "\\0007"')
        self.equivalent('return "a\\\nb"')
        self.equivalent('local f=function() return 1,2 end; return (f())')

    def test_standard_function_caching(self):
        result, cached = self.equivalent('local t={}; table.insert(t,1); table.insert(t,2); return table.concat(t,",")')
        self.assertEqual(cached, 1)
        self.assertEqual(result.count(b'table.insert'), 1)
        _, cached = self.equivalent('local math={floor=function(x) return x end}; return math.floor(2),math.floor(3)')
        self.assertEqual(cached, 0)
        _, cached = self.equivalent('table.insert=function(t,x) t[#t+1]=x+1 end; local t={}; table.insert(t,1); table.insert(t,2); return t[1],t[2]')
        self.assertEqual(cached, 0)
        _, cached = self.equivalent('local alias=table; local t={}; table.insert(t,1); table.insert(t,2); return alias.concat(t)')
        self.assertEqual(cached, 0)
        _, cached = self.equivalent('local env=getfenv(); return math.floor(1.5),math.floor(2.5),type(env)')
        self.assertEqual(cached, 0)

    def test_glua_and_comments(self):
        source = b'-- comment\nlocal items={} for index=1,3 do if index!=2 && !false then items[index]=index else continue end end /* removed */ return items'
        result, _ = self.minifier.minify(source)
        self.assertNotIn(b'comment', result)
        self.assertNotIn(b'removed', result)
        self.assertIn(b'continue', result)
        self.assertNotIn(b'index', result)

    def test_build_rebuild_and_failure_preserve_sources(self):
        with tempfile.TemporaryDirectory(prefix='bgn build test ') as temporary:
            root = Path(temporary)
            (root / 'lua/nested').mkdir(parents=True)
            source = root / 'lua/nested/test.lua'
            source.write_bytes(b'-- comment\nlocal value=42; return value')
            (root / 'materials').mkdir()
            asset = root / 'materials/test.vmt'
            asset.write_bytes(b'"UnlitGeneric" {}')
            (root / 'models').mkdir()
            model = root / 'models/test.mdl'
            model.write_bytes(b'model')
            (root / 'models/test.sw.vtx').write_bytes(b'excluded')
            (root / 'models/source.blend').write_bytes(b'excluded')
            (root / 'addon.json').write_text('{"title":"Test","type":"npc","tags":["fun"]}')
            (root / 'LICENSE').write_text('License')
            (root / 'tools').mkdir()
            (root / 'tools/dev.lua').write_text('error("must not ship")')
            original = {file: hashlib.sha256(file.read_bytes()).digest() for file in (source, asset, model)}
            with patch.object(build_addon, 'Minifier', return_value=self.minifier):
                output = build_addon.build(root)
                self.assertFalse((output / 'tools').exists())
                self.assertFalse((output / 'models/test.sw.vtx').exists())
                self.assertFalse((output / 'models/source.blend').exists())
                self.assertTrue((output / 'materials').is_symlink() or (output / 'materials').is_junction())
                self.assertTrue((output / 'models/test.mdl').samefile(model))
                self.assertNotIn(b'comment', (output / 'lua/nested/test.lua').read_bytes())
                (output / 'stale.txt').write_text('old build')
                build_addon.build(root)
                self.assertFalse((output / 'stale.txt').exists())
                for file, digest in original.items():
                    self.assertEqual(hashlib.sha256(file.read_bytes()).digest(), digest)
                successful = (output / 'lua/nested/test.lua').read_bytes()
                source.write_text('local =')
                with self.assertRaisesRegex(RuntimeError, 'Source GLua syntax'):
                    build_addon.build(root)
                self.assertEqual((output / 'lua/nested/test.lua').read_bytes(), successful)
                source.write_bytes(b'return 42')
                with patch.object(self.minifier, 'minify', return_value=(b'local =', 0)):
                    with self.assertRaisesRegex(RuntimeError, 'GLua syntax validation'):
                        build_addon.build(root)
                self.assertEqual((output / 'lua/nested/test.lua').read_bytes(), successful)

    def test_cache_checksum(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary)
            (cache / 'minify.lua').write_bytes(b'untrusted cache')
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                build_addon.download_minifier(cache)

    @unittest.skipUnless(os.name == 'nt', 'Windows junction fallback')
    def test_junction_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'materials'
            source.mkdir()
            (source / 'test.vmt').write_bytes(b'asset')
            error = OSError('Symbolic link privilege unavailable')
            error.winerror = 1314
            with patch.object(Path, 'symlink_to', side_effect=error):
                build_addon.link_resources(source, root / 'linked')
            self.assertTrue((root / 'linked').is_junction())
            self.assertTrue((root / 'linked/test.vmt').samefile(source / 'test.vmt'))

    def test_reject_linked_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / 'outside'
            target.mkdir()
            build_addon.link_resources(target, root / 'build')
            with self.assertRaisesRegex(RuntimeError, 'linked build directory'):
                build_addon.build(root)
            self.assertTrue(target.exists())


if __name__ == '__main__':
    unittest.main()
