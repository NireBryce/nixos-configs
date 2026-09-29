# 2. The repo is not the machine

_Last modified: 2026-09-29_

§2 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §2's full account.

The most expensive error of the port, made three times.

- Diagnosed impermanence as "inert since April". It was inert in *this branch*,
  which had never been deployed; `origin/main` carried the working version and
  that is what the machines ran.
- Wrote that tenacity had never had Home Manager, on the sibling handoff's
  authority. True of that branch, false of the machine.
- Several facts were simply not in the repo — that `root-blank` exists, that
  both disks are formatted alike. Each was one question to the person who owns
  the machines.

**Before claiming production impact, find out what is deployed.** When a claim
is about hardware, ask.
