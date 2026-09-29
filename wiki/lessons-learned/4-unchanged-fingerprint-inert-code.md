# 4. An unchanged fingerprint can mean the code is inert

_Last modified: 2026-09-29_

§4 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §4's full account.

Editing `boot.initrd.systemd.services.restore-root` left the initrd
byte-identical every time — not because the edits were equivalent, but because
that unit is only rendered under systemd stage 1, which was off. The service was
never built into anything.

**An identical fingerprint after a change you expected to matter is a signal to
investigate, not to relax.**
