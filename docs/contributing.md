# Building the docs

From the repository root:

```text
python -m pip install -r requirements-docs.txt
python -m mkdocs serve
```

Open the address printed in the terminal. Before committing:

```text
python -m mkdocs build --strict
```

English pages use `.md`; Russian siblings use `.ru.md`. Link to `.md` paths: the plugin resolves the selected language and falls back to English for missing translations. Preserve existing page paths for external links.

The workflow checks pull requests and deploys only on pushes to master. GitHub Actions needs write access, and GitHub Pages must serve the gh-pages branch. Local builds publish nothing.

Before changing public behavior, read [AI documentation rules](ai.md) and [architecture](architecture.md). Update both languages and the relevant realm reference with the code; preserve page URLs. See [history](history.md) for the baseline and release boundaries.

## Local Workshop build

On Windows, install Python 3.12+ and put `glualint` in PATH. Install the build dependency once:

```text
python.exe -m pip install -r requirements-build.txt
```

Run `build.bat` from any working directory, or double-click it. The result is
`build/background-citizens/`: a Workshop addon folder containing `addon.json`,
the license, minified `lua/` and linked game resources. `build/` is ignored by Git.
The build does not upload anything or change the source Lua files.

The first build downloads [glua-minify](https://github.com/TRIGONIM/glua-minify)
at commit `4d19b690faf5e9cd3786d60609f6a02b6f645130` into `build/.tools/`, verifies
its SHA-256, and runs it through Lupa's LuaJIT. Subsequent builds use the verified
cache without downloading it again. The adapter fixes parser/scope issues for
`goto`/labels, implicit method `self`, repeat-loop locals and global-name collisions.

Each Lua file becomes one physical line: comments and unnecessary whitespace
are removed, local variables/functions/parameters receive shorter names, and
multiline string values are preserved using escapes. Public methods, globals,
table keys, paths and the SERVER/CLIENT/SHARED file layout keep their names.
Comment-only files become `return` because GMad rejects empty files.

Repeated direct calls to selected standard `math`, `string` and `table` functions
are cached in file-local variables. Calls through shadowed libraries are left
alone; detected library writes/aliases or dynamic environment access disable the
affected caching. **Caching assumes other addons do not replace these standard
functions after this file loads.** GMod APIs and hooks remain dynamic. This is
source minification with limited lookup optimization, not a promise of higher FPS
or C++-style whole-program optimization. Debug stack traces lose source line detail.

Resources are linked from `materials/` (`vmt/vtf/png/jpg/jpeg`), `models/`
(`mdl/vvd/vtx/phy/ani`), `sound/` (`wav/mp3/ogg`) and `resource/`
(`properties/ttf`). Other extensions and Workshop-incompatible `*.sw.vtx` are
excluded. A whole-directory symbolic link is used when every file is included;
otherwise the build links individual included files. Windows falls back to
directory junctions and file hard links when symbolic links need extra privileges.
**Treat linked resources as read-only: editing them edits the working tree.**
These links also mean resource changes appear in an existing build immediately;
rebuild before packaging to refresh Lua and the resource selection. The build folder
is not a standalone copy to move to another machine.

Both source and generated Lua must pass `glualint dump-ast`. A failed transform
or syntax check leaves the previous successful output intact. A successful rebuild
replaces only `build/background-citizens/`, removing stale generated files. Other
files under `build/` are retained. Development tools, docs and quarantined files
are not included. To create a `.gma`, pass this output folder to GMad using the
[Workshop packaging instructions](https://wiki.facepunch.com/gmod/Workshop_Addon_Creation).

Build regression checks:

```text
python.exe -m unittest discover -s tools -p test_build.py -v
```

These checks cover transformations and output handling outside the game; test the
generated addon in GMod before publishing it.
