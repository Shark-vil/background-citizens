# AI entry point: documentation maintenance

Read this page, [architecture](architecture.md), [version history](history.md), and the affected source before editing. Root `AGENTS.md` points here.

## Source of truth

1. Read `git status`, branch/HEAD, `version.txt` and `bgNPC.VERSION` in `sh_init.lua`. Preserve unrelated work.
2. Compare release tags and commits through the requested version, then inspect subsequent commits present in the working tree. Separate a tagged release from later branch changes; never label dev behavior as released on Workshop.
3. Code and load order decide contracts. Plans, old comments, MODLOG and an existing documentation page are evidence to verify, not proof of implementation.
4. Check function definitions, every caller, realm guards, network receivers and optional-dependency availability. A `sh_` prefix alone is insufficient to classify supported usage.

## What to update together

| Change | Documentation affected |
|---|---|
| Public signature / return / alias | Realm reference, method page, callers in examples and tutorials; preserve old URLs. |
| Gameplay / default / command | System page, settings/config guide, troubleshooting when relevant, history. |
| File layout / loading / event flow | Architecture and this maintenance map. |
| New page | EN/RU siblings, `mkdocs.yml` navigation + Russian label, index links. |
| Release boundary | History baseline, architecture version/commit, README and entry pages. |

Use `reference/server.md`, `client.md`, `shared.md` as the API entry points. Explain authority and client snapshot limits. Record nil/NULL, argument defaults, validation, side effects, hook cancellation and entity replacement when relevant. Keep modern APIs primary and label actual compatibility aliases; do not invent a replacement for a missing method.

## Writing rules

- English: `.md`; Russian sibling: `.ru.md`. Keep both semantically aligned. Signatures and source paths stay literal.
- Internal site links use `.md` even on Russian pages; i18n resolves the locale. Keep existing filenames/URLs and replace obsolete contents with a migration explanation.
- Explain a system once and link to it. Keep rules/defaults on the owning page, implementation structure in architecture, historical differences in history.
- Prefer small tables, runnable minimal examples and precise contracts. Do not add dependencies or runtime code for a documentation task.
- Never include tokens, private machine paths, temporary bridge instructions presented as installation requirements, or unsupported performance claims.
- Do not edit generated `site/`. Do not treat ignored planning files as shipped instructions.

## Validation and handoff

Install existing `requirements-docs.txt` if needed, then run `python -m mkdocs build --strict`. Check internal links, anchors, EN/RU navigation, source paths and documented signatures against the code. Review `git diff --check` and the complete diff. A docs-only change does not require launching GMod or running physics fixtures; explicitly say what was not verified.

Update the baseline only after reviewing the covered changes. Commit only the intended documentation/config changes when the user requested a commit. Push or deployment is a separate action; the site's existing workflow deploys master, not every local commit.
