## what shipped

**One memory pruned.** `skill-descriptions-short.md` (the convention for
writing a skill's frontmatter `description`) was fully superseded by the
`new-skill` skill's own body, written after the memory existed. Repo content
should win over a private memory saying the same thing — the memory came
out rather than sitting as a stale duplicate nobody would ever notice
diverging. `MEMORY.md` is empty as of this session; not a mistake, there
was genuinely only the one memory and it's gone now.

**`propose-issue` step 2 de-duplicated.** It was hand-grepping `CLAUDE.md` +
`lessons-learned.md` and separately calling
`gh issue list --search "<keywords>"` — exactly what
`flake/scripts/threads.sh` (`just threads`) already does in one shot, and
which `investigate-bug` already points at. Changed step 2 to call
`just threads` instead of re-deriving the same check by hand in a second
place.

**`just preflight` added.** `check` + `modules` + `lint` in one recipe —
what `ship`'s step 0 already told a session to run by hand, now one command.
`ship`'s SKILL.md updated to mention it.

## the actual finding, generalized

Both real hits here were the same shape: a skill re-describing, in prose,
a check a script already performs correctly. Not a skill being wrong,
exactly — just not pointing at the thing that already exists. Worth
re-checking whenever a procedural skill's body grows past roughly 150
lines, since that's about where hand-written steps start accumulating
faster than anyone cross-checks them against `flake/scripts/`.
