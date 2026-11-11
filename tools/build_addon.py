"""Build a minified Workshop folder without changing the addon sources."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = {
    'materials': {'.vmt', '.vtf', '.png', '.jpg', '.jpeg'},
    'models': {'.mdl', '.vvd', '.vtx', '.phy', '.ani'},
    'sound': {'.wav', '.mp3', '.ogg'},
    'resource': {'.properties', '.ttf'},
}
MINIFIER_COMMIT = '4d19b690faf5e9cd3786d60609f6a02b6f645130'
MINIFIER_SHA256 = '7f2af1bd5cc491a1edd298c8f45a5d4280c3445a35eee0f15d59422aed6ff108'
MINIFIER_URL = f'https://raw.githubusercontent.com/TRIGONIM/glua-minify/{MINIFIER_COMMIT}/minify.lua'


def download_minifier(cache):
    path = cache / 'minify.lua'
    if not path.exists():
        print('Downloading pinned glua-minify (first build only)...', flush=True)
        with urllib.request.urlopen(MINIFIER_URL, timeout=30) as response:
            data = response.read()
    else:
        data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != MINIFIER_SHA256:
        raise RuntimeError(f'Minifier checksum mismatch: {path}')
    cache.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data.decode('utf-8')


def patch_minifier(source):
    # The archived parser lacks goto/labels and can shadow assigned globals.
    patches = [
        ("if debug.getinfo(2, \"n\").name == \"require\" then", 'if true then'),
        ("Digits[c3] or CharacterForEscape[c3]", "Digits[c3] or CharacterForEscape[c3] or c3 == '\\n' or c3 == '\\r' or c3 == 'a' or c3 == 'x' or c3 == 'z'"),
        ("\t\tif tok.Source == 'if' then", """
        if tok.Source == 'goto' or tok.Source == ':' then
            local first = get()
            local text
            if first.Source == 'goto' then
                text = 'goto '..expect('Ident').Source
            else
                expect('Symbol', ':')
                text = '::'..expect('Ident').Source..'::'
                expect('Symbol', ':')
                expect('Symbol', ':')
            end
            local token = {Source = text, LeadingWhite = first.LeadingWhite}
            return false, {
                Type = 'JumpStat', Token_Jump = token,
                GetFirstToken = function(self) return self.Token_Jump end,
                GetLastToken = function(self) return self.Token_Jump end
            }
        elseif tok.Source == 'if' then"""),
        ("stat.Type == 'BreakStat' or stat.Type == 'ContinueStat' then",
         "stat.Type == 'BreakStat' or stat.Type == 'ContinueStat' or stat.Type == 'JumpStat' then"),
        ("\t\telseif stat.Type == 'BreakStat' then\n\t\t\tprintt(stat.Token_Break)",
         "\t\telseif stat.Type == 'JumpStat' then\n\t\t\tprintt(stat.Token_Jump)\n\t\telseif stat.Type == 'BreakStat' then\n\t\t\tprintt(stat.Token_Break)"),
        ("\t\telseif stat.Type == 'BreakStat' then\n\t\t\tstript(stat.Token_Break)",
         "\t\telseif stat.Type == 'JumpStat' then\n\t\t\tstript(stat.Token_Jump)\n\t\telseif stat.Type == 'BreakStat' then\n\t\t\tstript(stat.Token_Break)"),
        ("var.AssignedTo = true\n\t\t\tpushScope()", """var.AssignedTo = true
            pushScope()
            local separators = stat.Token_NameChainSeparator
            if separators[#separators] and separators[#separators].Source == ':' then
                local implicit = addLocalVar('self', function() end, {Type = 'Argument'})
                implicit.Rename = function() end
            end"""),
        ("\tvisitor.AssignmentStat = {", """
    visitor.RepeatStat = { Pre = function(stat)
        pushScope()
        for _, child in ipairs(stat.Body.StatementList) do VisitAst(child, visitor) end
        VisitAst(stat.Condition, visitor)
        popScope()
        return true
    end }
    visitor.AssignmentStat = {"""),
    ]
    for old, new in patches:
        if old not in source:
            raise RuntimeError('Pinned minifier patch no longer applies')
        source = source.replace(old, new)
    # Reserve every global, including names assigned by this file.
    source = source.replace('local externalGlobals = {}',
                            'local externalGlobals = {}; for _, v in pairs(globalScope) do externalGlobals[v.Name] = true end')
    # A digit touching concatenation becomes a malformed number (1..x).
    source = source.replace("(lastCh == '-' and firstCh == '-') or",
                            "(lastCh == '-' and firstCh == '-') or (Digits[lastCh] and firstCh == '.') or")
    return source


class Minifier:
    def __init__(self, cache):
        try:
            from lupa.luajit21 import LuaRuntime
        except ImportError as exc:
            raise RuntimeError('Install build dependencies: python.exe -m pip install -r requirements-build.txt') from exc
        self.lua = LuaRuntime(encoding=None, unpack_returned_tuples=True)
        module = self.lua.execute(patch_minifier(download_minifier(cache)).encode('utf-8'))
        factory = self.lua.execute((ROOT / 'tools/build_minify.lua').read_bytes())
        self.convert = factory(module)

    def minify(self, source):
        return self.convert(source.removeprefix(b'\xef\xbb\xbf'))


def link_resources(source, destination):
    files = [file for file in source.rglob('*') if file.is_file()]
    included = [file for file in files if file.suffix.lower() in RESOURCES[source.name]
                and not file.name.lower().endswith('.sw.vtx')]
    if len(included) != len(files):
        # A whole-directory link would also expose development/unsupported files.
        destination.mkdir()
        for file in included:
            link = destination / file.relative_to(source)
            link.parent.mkdir(parents=True, exist_ok=True)
            try:
                link.symlink_to(file)
            except OSError as exc:
                if os.name != 'nt' or exc.winerror != 1314:
                    raise
                os.link(file, link)
        return
    try:
        destination.symlink_to(source, target_is_directory=True)
    except OSError as exc:
        if os.name != 'nt' or exc.winerror != 1314:
            raise
        # Directory junctions work without Developer Mode or administrator rights.
        subprocess.run(
            ['powershell.exe', '-NoProfile', '-NonInteractive', '-Command',
             'New-Item -ItemType Junction -Path $env:BGN_BUILD_LINK -Target $env:BGN_BUILD_SOURCE -ErrorAction Stop | Out-Null'],
            env={**os.environ, 'BGN_BUILD_LINK': str(destination), 'BGN_BUILD_SOURCE': str(source)},
            check=True, capture_output=True,
        )


def reject_link(path):
    if path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction()):
        raise RuntimeError(f'Refusing to replace linked build directory: {path}')


def build(root=ROOT):
    if sys.version_info < (3, 12):
        raise RuntimeError('Python 3.12 or newer is required')
    validator = shutil.which('glualint')
    if not validator:
        raise RuntimeError('glualint was not found in PATH')
    build_dir = root / 'build'
    reject_link(build_dir)
    build_dir.mkdir(exist_ok=True)
    output = build_dir / 'background-citizens'
    reject_link(output)
    print('Validating source Lua with glualint...', flush=True)
    validation = subprocess.run([validator, 'dump-ast', str(root / 'lua')], capture_output=True)
    if validation.returncode:
        raise RuntimeError('Source GLua syntax validation failed:\n' +
                           (validation.stdout + validation.stderr).decode('utf-8', errors='replace'))
    minifier = Minifier(build_dir / '.tools')
    before = after = aliases = count = 0
    with tempfile.TemporaryDirectory(prefix='.staging-', dir=build_dir) as temporary:
        stage = Path(temporary) / 'background-citizens'
        stage.mkdir()
        for source in sorted((root / 'lua').rglob('*')):
            if not source.is_file():
                continue
            if source.suffix != '.lua':
                raise RuntimeError(f'Unexpected non-Lua file in lua/: {source}')
            data = source.read_bytes()
            try:
                result, cached = minifier.minify(data)
            except Exception as exc:
                raise RuntimeError(f'Minification failed: {source.relative_to(root)}\n{exc}') from exc
            destination = stage / source.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(result)
            before += len(data)
            after += len(result)
            aliases += cached
            count += 1
        if not count:
            raise RuntimeError('No Lua files found')
        print(f'Validating {count} minified Lua files with glualint...', flush=True)
        validation = subprocess.run([validator, 'dump-ast', str(stage / 'lua')],
                                    capture_output=True)
        if validation.returncode:
            raise RuntimeError('GLua syntax validation failed:\n' +
                               (validation.stdout + validation.stderr).decode('utf-8', errors='replace'))
        shutil.copy2(root / 'addon.json', stage / 'addon.json')
        shutil.copy2(root / 'LICENSE', stage / 'LICENSE')
        for name in RESOURCES:
            if (root / name).is_dir():
                link_resources((root / name).resolve(), stage / name)
        # Only remove this generated folder, after the replacement is ready.
        reject_link(output)
        if output.parent.resolve() != build_dir.resolve():
            raise RuntimeError('Build output escaped build/')
        if output.exists():
            shutil.rmtree(output)
        stage.replace(output)
    print(f'Built: {output}\nLua: {count} files, {before:,} -> {after:,} bytes '
          f'({100 * (1 - after / before):.1f}% smaller); {aliases} cached standard functions.')
    print('Resources are links to the working tree. No upload was performed.')
    return output


if __name__ == '__main__':
    try:
        build()
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
