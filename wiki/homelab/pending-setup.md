# Pending setup

_Last modified: 2026-10-01_

Services that are **running but not finished**: configured, switched,
reachable, and still missing the human step that makes them useful. Each
such step is something to do *to a live service*, in a browser or over
ssh, not a change to `flake/modules/`, which is why no commit can close
it. Since 2026-10-01 each one is a GitHub issue with the `pending-setup`
label, not an entry on this page; status lives on the issue.

> **Condensed version:**
> [pending-setup-for-agents.md](pending-setup-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [The list](#the-list)
- [How this differs from open-threads.md](#how-this-differs-from-open-threadsmd)
- [Done, and still worth knowing](#done-and-still-worth-knowing)
- [See also](#see-also)

## The list

```sh
gh issue list --repo NireBryce/nixos-configs --label pending-setup
```

What the label means: a one-time step done in a service's own database or
UI (an account, a link, a value only a human can supply), with a "done
when" that is checked on the live service, not by `nix eval`. When a step
like this turns up, file it with that label rather than adding it here.

At the move (2026-10-01) the label covered the first go/ links
(#TBD-golink-first-links), a push over SSH to the forge
(#TBD-forge-ssh-push), and homepage's calendar feeds
([#299](https://github.com/NireBryce/nixos-configs/issues/299)).

## How this differs from open-threads.md

[open-threads.md](../open-threads.md) is the *repo's* loose ends: todos
left in code, upstream bugs, deferred design decisions. This label is the
*fleet's*: operational setup that lives in a service's own database rather
than in Nix. An item can be both; backups were, until 2026-09-06
([#87](https://github.com/NireBryce/nixos-configs/issues/87)).

## Done, and still worth knowing

The items this page used to carry as "done" are recorded where they
belong now; the outcomes that change how you work:

- **The forge is a mirror, not an origin; GitHub stays canonical** —
  decided 2026-09-03, reaffirmed 2026-09-12 once backups were proven.
  Reopening it is a fresh decision.
  [git-forge-history.md](../categories/git-forge-history.md#mirror-not-origin--and-the-first-real-mirror).
- **Backups exist and a real restore has recovered a Forgejo database**
  (2026-09-06). [backup-history.md](../categories/backup-history.md#the-setup-checklist-closed-out-2026-08-28-through-2026-09-06),
  procedure in [backup-runbook.md](backup-runbook.md).
- **A Grafana dashboard edited in the UI lives only in cube's sqlite
  db**: backed up, so it survives a restore, but not a rebuild that
  reprovisions `_dashboards/`. Keep one by exporting it into the repo:
  [monitoring.md](../categories/monitoring.md#adding-a-dashboard-that-survives-a-rebuild).
- Grafana's admin password and the Forgejo Actions runner's bootstrap are
  closed; [maintenance-schedule.md](../maintenance-schedule.md) and
  [git-forge](../categories/git-forge.md) carry their current state.

## See also

- [Reaching cube's services](reaching-services.md) — the URLs, and what to
  check when one doesn't answer.
- [Using the forge](forgejo.md) — clone URLs, sign-in, adding an SSH key.
- [Creating go/ links](creating-golinks.md) — read its traps before the
  first link.
- [open-threads.md](../open-threads.md) — the repo-side counterpart.
