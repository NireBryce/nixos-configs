# 15. Commit hygiene

_Last modified: 2026-09-29_

§15 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §15's full account.

- **A commit message must not describe state that does not exist.** One referred
  to a note not yet written; the next commit had to make it true.
- **Check what is staged before writing the message.** One commit swept 24 files
  in alongside a two-file rename; another quietly included a change the message
  never mentioned. Staging early — `git add` before `nix eval`, which flakes
  require — makes both easy to do by accident.
- **Order commits so each is green.** A checker fix and the refactor needing it
  landed checker-first; the other order leaves an intermediate commit where
  `just modules` fails. Verified in a throwaway worktree.
- **Git authorship does not say who wrote it.** Every commit here is authored by
  the user, including ones written by an agent.
