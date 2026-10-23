# docs-audit-parallel

- **Source:** `.agents/skills/docs-audit-all/SKILL.md` (+ the `just agent doc-drift` and `doc-partition` helpers it names)
- **General kernel:** audit every documented claim against the code by partitioning all docs among parallel subagents that each own disjoint files, ranking by cited-code churn since each doc's last-modified date, with a fixed report format and a second behavioral pass over anything only checked mechanically.
- **Strip/replace:** `just` recipe names, the wiki lint command, worktree skill name, sibling-page rule, commit id.
- **Evidence:** one run (commit `0abcb9de`) fixed about 50 errors in a lint-clean tree; no enforcing check beyond `doc-partition` failing on an unowned doc.
- **Depends on:** none.
- **Recorded:** 2026-10-22
