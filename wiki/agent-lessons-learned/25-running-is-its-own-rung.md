# 25. Running it is a rung of its own, and finds a different class

_Last modified: 2026-09-29_

## Index entry

§25 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the longer write-up.

## The lesson

Switching put this branch on the hardware, and four things broke that neither
evaluation nor a successful build could see:

- VS Code launched pointed at an empty store directory as its extensions dir
- `ble-attach` ran ahead of seven other shell integrations
- `handheld-daemon` died on `import pkg_resources`
- suspend wrote a 2.3G hibernation image on every sleep

The daemon is the clean case: it evaluated, it *built*, and it failed on the
first line it executed, because a missing import is a runtime event.
