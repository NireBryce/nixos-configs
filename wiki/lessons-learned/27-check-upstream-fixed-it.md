# 27. Check whether upstream already fixed it before writing the patch

_Last modified: 2026-09-29_

§27 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §27's full account.

`handheld-daemon` imports `pkg_resources`, which setuptools 83 removed. That got
a 45-line bespoke shim, and it worked, and it was the wrong artefact — upstream
had already replaced it with `importlib.metadata` in 4.1.12, in five lines.

Size is not the point: a backport of upstream's own change deletes cleanly when
nixpkgs catches up, where an invention has to be reconciled with whatever
upstream actually did. The same file settled a second question the first patch
got wrong — `pyproject.toml` says `where = ["src"]`, so the paths were `src/hhd/`.

**Read the project's current source and packaging metadata before writing
compatibility code.**
