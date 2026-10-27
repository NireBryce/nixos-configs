# 14. Read the repo's own conventions before writing into it

_Last modified: 2026-09-29_

## Index entry

§14 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the longer write-up.

## The lesson

`manconfig.nix` was written with a 25-line header and rejected for not matching
its neighbours. The repo had a style guide all along, four levels down beside
the package modules with nothing linking to it. `grep -ri 'style\|convention'
--include='*.md'` costs nothing.
