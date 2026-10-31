# delete-by-verified-pr-facts

- **Source:** `.agents/scripts/ship.py` (`gate_problems`, `land`), `.agents/scripts/worktree.py` (`PROTECTED`), `wiki/agent-lessons-learned/52-derive-deletes-from-verified-facts.md`
- **General kernel:** a land-and-clean-up script reads `isCrossRepository`, `headRefName`, `headRefOid` and `baseRefName` from the PR, refuses before merging when the head is in a fork, protected, or equals the base (a missing field counts as unsafe), merges with `--match-head-commit`, deletes with `-d` and uses `-D` only when the local tip equals the verified head, and skips the remote delete while another open PR is based on the branch.
- **Strip/replace:** the protected-branch names, the `just agent` entry points, the fake-`gh` fixtures.
- **Evidence:** the same hole existed in six places across five repos; tests written first failed on the old code.
- **Depends on:** none.
- **Recorded:** 2026-10-31
