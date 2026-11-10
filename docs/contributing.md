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
