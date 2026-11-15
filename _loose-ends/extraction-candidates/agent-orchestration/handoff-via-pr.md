# handoff-via-pr

- **Source:** `.agents/skills/handoff/SKILL.md`
- **General kernel:** to end a long agent session without carrying its history forward, commit the task to a branch and open a PR whose body (what changed, why with the decisions and rejected options, what was verified, what was left alone, what is open, the next step) is the handoff note; the next session starts from the PR number and reads the PR, so nothing is pasted between sessions and the state lives in the forge.
- **Strip/replace:** `just agent commit` / `just agent pr` / `just agent where`, the `ship` and `use-a-worktree` skill references, the public-repo and `elly/infra-notes` security rule, the `Needs: bash-guards` tag, the disclosure line and risk-and-impact scale from this repo's PR template.
- **Evidence:** none yet; written 2026-11-15 from a measurement of session transcripts (long sessions re-read their whole history on every call). Unused so far.
- **Depends on:** a PR template and a commit/PR script to call, and the no-merge boundary with a separate landing skill (`ship`).
- **Recorded:** 2026-11-15
