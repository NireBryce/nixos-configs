# Pending setup, for agents

_Last modified: 2026-10-01_

Condensed from [pending-setup.md](pending-setup.md).

Not a tracker since 2026-10-01. Open items are issues:
`gh issue list --repo NireBryce/nixos-configs --label pending-setup`.
Label = one-time step in a live service's own database/UI (browser/ssh,
never `flake/modules/`); "done when" is checked live. New one → file with
that label, don't add it here. Repo-side counterpart:
[../open-threads-for-agents.md](../open-threads-for-agents.md).

## Settled, load-bearing

- Forge is a **mirror**, GitHub canonical — settled 2026-09-12, not open.
  [../categories/git-forge-history.md](../categories/git-forge-history.md).
- Backups + a real restore proven 2026-09-06 (#87).
  [../categories/backup-for-agents.md](../categories/backup-for-agents.md).
- Grafana UI-edited dashboards live only in cube's sqlite db: survive a
  restore, not a rebuild. Export into `_dashboards/` to keep.
- Unauthenticated Forgejo `users/search` masks `last_login`/`is_admin`;
  never read it as "nobody signed in".
  [../categories/git-forge-for-agents.md](../categories/git-forge-for-agents.md).

See also: [reaching-services.md](reaching-services.md#quick-facts) ·
[creating-golinks.md](creating-golinks.md#quick-facts) ·
[forgejo-for-agents.md](forgejo-for-agents.md)
