# 25. Running it is a rung of its own, and finds a different class

_Last modified: 2026-09-29_

§25 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §25's full account.

Switching put this branch on the hardware, and four things broke that neither
evaluation nor a successful build could see:

- VS Code launched pointed at an empty store directory as its extensions dir
- `ble-attach` ran ahead of seven other shell integrations
- `handheld-daemon` died on `import pkg_resources`
- suspend wrote a 2.3G hibernation image on every sleep

The daemon is the clean case: it evaluated, it *built*, and it failed on the
first line it executed, because a missing import is a runtime event.
