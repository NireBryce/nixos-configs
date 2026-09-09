# REPORT — repo audit, setup, and recommendations

_As of: 2026-09-08. Written by an agent after a read-only audit of the tree,
the GitHub repo (`NireBryce/nixos-configs`), and the automation. Factual
claims cite the file or command they came from; counts are snapshots of this
date and will rot — the living sources are the files cited, not this report._

This directory is **separate from `wiki/` on purpose**, per the request that
commissioned it. The wiki remains the canonical topic index; these pages are
an outside-in description of how the repo is set up, plus recommendations.
They are not covered by `wiki-lint` (which scopes itself to `wiki/` and
`AGENTS.md`), so links here go unchecked — treat them as a dated snapshot,
not a maintained reference.

## Contents

- [01-overview.md](01-overview.md) — what this repo is, and a top-to-bottom tour of every top-level path, including the doc tiers and the safety story.
- [02-architecture.md](02-architecture.md) — the flake: flake-parts, `import-tree`, `flake.modules`, `dirsAsCategory`, host construction, Home Manager integration, checks and invariants.
- [03-conventions-and-style.md](03-conventions-and-style.md) — Nix code style, naming, comments and history, commit and docs conventions, the trap catalogue.
- [04-workflows-and-tooling.md](04-workflows-and-tooling.md) — `just`, `flake/scripts/`, verification practice, the lint ratchet, wiki-lint, secrets operations, agent harness (skills/hooks), editor and dev shells.
- [05-github-usage.md](05-github-usage.md) — trunk + promotion branch model, rulesets, CI workflows, the weekly lock PR and its PAT, issue/PR templates, issue-tracker discipline.
- [06-recommendations.md](06-recommendations.md) — consolidated, prioritized findings and recommended changes.

## Method

- Direct reads: `README.md`, `AGENTS.md`, `.justfile`, `flake/flake.nix`,
  `flake/modules/nireHost/hosts.nix`, `wiki/module-style-guide.md`,
  `.claude/skills/ship/SKILL.md`, `.sops.yaml`, `.gitignore`, `.vscode/`.
- Two parallel read-only explorations covered `.github/`, `.githooks/`,
  `flake/scripts/`, `wiki/`, `flake/doc/`, `.claude/skills/`,
  `_lab-notebook-nixos/`, `bugs pending submission/`, and the git/PR history.
- The audit session found the shared checkout on branch
  `fix/bare-name-ssl-certs` with staged changes to
  `flake/modules/nire/homelab/reverse-proxy/caddy/caddy.nix` and
  `.../tailscale-services/serve.nix` — someone else's in-progress work. This
  report only added untracked files under `REPORT/` and touched nothing else.
  If this file is missing, `git clean` or a checkout change ate it — see
  `AGENTS.md`, "Working in this repo", on shared checkouts and worktrees.

## Reading order

New to the repo: 01 → 02 → 05. Here to act on the findings: 06 (everything
else is evidence). Here for a specific convention: 03 or 04.
