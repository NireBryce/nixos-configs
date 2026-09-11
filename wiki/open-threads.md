# Open threads

_Last modified: 2026-09-11_

## Contents

- [Tracked as GitHub issues](#tracked-as-github-issues)
- [Pending upstream bug reports](#pending-upstream-bug-reports)
- [Todos and ideas left next to the code](#todos-and-ideas-left-next-to-the-code)
- [Left open by the cube service stack, 2026-08-24](#left-open-by-the-cube-service-stack-2026-08-24)
- [Not covered here](#not-covered-here)

> **Condensed version:**
> [open-threads-for-agents.md](open-threads-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

Todos, half-formed ideas, and things-to-look-into notes left in various
corners of the tree, plus upstream bugs found here but not yet filed. None
of this is acted on just by being listed here — this page exists so these
don't have to be rediscovered by grepping the whole tree.

**Before starting work on any of these, or investigating a symptom that
might already be one of them: `gh issue list --search "<keywords>"` in
addition to grepping this page.** As of 2026-08-24 this repo actually files
GitHub issues (see below) rather than leaving everything here as prose —
started specifically because the ble.sh/carapace bug below had already been
independently rediscovered once, at real cost, before it was tracked this
way. `bugs pending submission/` (next section) is still the write-up stage
for a bug against a *third-party* project, before it's filed there; this
repo's own tracker is the issue queue, not another markdown list.

## Tracked as GitHub issues

- **[#205 — build the `flake.lock` bump on cube before proposing it,
  instead of only evaluating it in
  CI](https://github.com/NireBryce/nixos-configs/issues/205)** — open,
  filed 2026-09-08. The weekly lock workflow (#204) can only *evaluate*:
  `nix flake check + module tree` forces each host's toplevel as an
  evaluation, and CI never builds it, so an input bump that evaluates fine
  and breaks a host stays invisible until someone runs `just switch` on
  real hardware — §§36–37 exactly. cube is `x86_64-linux` and already runs
  scheduled work against a sops credential
  ([restic.nix](../flake/modules/nire/homelab/backup/restic/restic.nix) is
  the precedent for the whole shape), so it can do what a runner
  structurally cannot. Note this **relocates** the PAT rather than removing
  it — same scopes, same expiry, `/run/secrets/` instead of a GitHub
  Actions secret — so it is a wash on credential hygiene, and
  [maintenance-schedule.md](maintenance-schedule.md) item 10's "Why not
  sops" reasoning would need rewriting if it lands.
- **[#87 — no backups anywhere in the fleet; decide a scheme for cube's
  service state](https://github.com/NireBryce/nixos-configs/issues/87)** —
  **closed 2026-09-06.** restic-over-SFTP to the QNAP, with a real restore
  drill performed twice (once found and fixed a real `backupPrepareCommand`
  sqlite-staging bug, once more confirmed a clean restore) — the bar the
  issue itself set for "done". Full account:
  [backup.md](categories/backup.md) /
  [backup-history.md](categories/backup-history.md). Extending the same
  coverage to durandal/tenacity/lysithea is now
  **[#130](https://github.com/NireBryce/nixos-configs/issues/130)**.
- **[#75 — remove `carapace-completer-read-fix.bash` once ble.sh/carapace
  fix it upstream](https://github.com/NireBryce/nixos-configs/issues/75)**
  — open. The follow-on to #72 below: a local workaround stays in the tree
  until the real bug is fixed in one of the two projects it's actually in,
  and this is the reminder to check rather than let it sit unnoticed.
  Doesn't need revisiting on any particular schedule — but before assuming
  it's still needed just because nobody's looked, see its own "how to
  check" steps.
- **[#72 — ble.sh + carapace: spurious `read: `': not a valid identifier` on
  Tab / auto-complete](https://github.com/NireBryce/nixos-configs/issues/72)**
  — closed 2026-08-24, confirmed via a real `just switch` on `nire-cube`.
  Kept listed here as a worked example of the "check first" pattern this
  section's own header describes. Full diagnosis:
  [blesh.md](categories/shell-config/blesh.md).

## Pending upstream bug reports

`bugs pending submission/` — written up, not yet filed against the
third-party project itself, and **not filed by anyone here on their own
initiative**: per `CLAUDE.md`, filing outside `NireBryce/nixos-configs`
happens only when Elly says so explicitly, in those words, for that
specific report — not as a housekeeping pass over this list:

- **[nixpkgs: vscode ≥ 1.129 patches the wrong ripgrep on Linux](<../bugs pending submission/2026-08-11-bugreport-nixpkgs-vscode-ripgrep.md>)**
  (2026-08-11, still present on nixpkgs `master` as of that date).
- **[amd-s2idle: hardware sleep residency reported 100× too high](<../bugs pending submission/2026-08-12-bugreport-amd-s2idle-residency-percent.md>)**
  (2026-08-12, against `amd-debug-tools` 0.2.20).
- **[Jovian-NixOS: `amd_iommu=off` blocks s0i3 on non-Deck handhelds with an NPU](<../bugs pending submission/2026-08-12-bugreport-jovian-amd-iommu-s0i3.md>)**
  (2026-08-12, found on a GPD G1617-02-L).

## Todos and ideas left next to the code

- **[`../flake/scripts/script-wishlist.md`](<../flake/scripts/script-wishlist.md>)**
  — bare headings only (`vicinae`, `just`, `espanso`, `other`), no content
  yet. A placeholder for future script ideas, not current work.
- **Are the `peripherals` modules (`logitech-g600`/`zsa-moonlander`) still
  wanted on a handheld? Is full desktop package parity still wanted on
  tenacity?** Two open questions, neither decided, rescued from a deleted
  handoff doc into `claude cave/2026-08-09 things to look into
  eventually.md` — itself removed 2026-09-01 (still in git history; also
  carried a security-hardening reference link, now only recoverable there).
- `claude cave/2026-08-24-evaluation-self-hosted-booking.md` (removed
  2026-09-01, still in git history if wanted) — Easy!Appointments vs
  LibreBooking, compared 2026-08-24 and explicitly not pursued. What's
  recorded: they aren't competitors (one books a person's time, the other
  books a *thing*), **neither is in nixpkgs and neither has a NixOS
  module**, and the unanswered first question if it restarts: both are PHP
  apps wanting a writable install dir, so podman-vs-hand-written-module.
  Also corrected a from-memory claim about Cal.com's license.
- **[`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>)**
  ends with a "things to look into" list — MyNixOS, nixpkgs-wayland,
  nix-direnv, haumea, flakelight, flake-utils(-plus), devshell, devbox,
  devenv, nixos-shell, nix-index, nix-prefetch — and an unanswered "learn
  what `outputs @ inputs:` means and figure out specialArgs" note. Also
  covered from the fix-snippet angle on [conventions.md](conventions.md).
- **Forgejo: no local CI/CD yet.** `pending-setup.md` and `forgejo.md` cover
  getting the forge itself usable; running Forgejo Actions against it (to
  mirror what GitHub Actions does in `.github/workflows/`, on
  locally-hosted infrastructure instead) hasn't been started. Rescued
  2026-09-08 from a removed notebook TODO, itself already superseded on its
  other point (the "manual migration steps" question — answered by
  `pending-setup.md`'s mirror decision).
- **CI's lint step re-fetches `nixpkgs#statix nixpkgs#deadnix` from the
  binary cache on every run** (`.github/workflows/check.yml`), rather than
  reusing the flake's own nixpkgs input (already in the tree as
  home-manager packages, per `nirePackages/nix-utils/`). Cheap today; worth
  pinning if CI minutes ever start mattering. Rescued 2026-09-08 from a
  removed notebook.
- **QNAP NAS: no way to disable SSH password authentication in the QNAP's
  own OS (QuTS hero) if SSH access to it is ever enabled there** — separate
  from the restic-over-SFTP credentials in
  [maintenance-schedule.md](maintenance-schedule.md) item 5, which cover
  `nire-cube`'s side of that connection, not the NAS's own sshd config.
  Mitigations undecided; rescued 2026-09-08 from a removed notebook,
  unanswered there too.

`nire-llm-sandbox`'s three runtime-verified `VMs/_lib/libvirt-vm.nix` fixes
(default network never started, a nonexistent `virsh` flag, a missing fixed
domain UUID) used to be recorded here; the VM itself was removed 2026-08-28
— see [history.md](history.md) and [lessons-learned.md](lessons-learned.md)
§40 for that detail now.

## Left open by the cube service stack, 2026-08-24

Four things the reverse-proxy/glance work knowingly did not do. None is a
bug; each is a decision someone might otherwise re-litigate from scratch.

- **Done.** `nire-cube` was running a config activated from
  `~/nixos-caddy-test/`, a plain rsync of a working tree, while its real
  checkout at `~/nixos-configs` sat several commits behind `main`. Both
  since resolved: the checkout is caught up with `main` and `~/nixos-caddy-test`
  has been deleted. Sync-and-build-over-ssh exists because a darwin session
  cannot build an `x86_64-linux` toplevel; see the `new-homelab-service`
  skill.
- **Nothing backs up `/var/lib/forgejo`** — or anything else on cube.
  **Now tracked as
  [#87](https://github.com/NireBryce/nixos-configs/issues/87)** (whole
  fleet, not just the forge); documented at
  [homelab/forgejo.md](homelab/forgejo.md) so nobody mistakes the forge for
  durable storage. A [backup](categories/backup.md) category landed
  2026-08-28 implementing #87's scheme, switched and running on cube as of
  2026-08-30 — but as local-path restic over NFS, which failed for real (an
  export ACL the QNAP never granted cube), so SFTP since 2026-08-31. **Done
  as of 2026-09-06**: sops secrets set, anti-deletion snapshot schedule
  confirmed live, and the restore drill (#87's own bar for "done") actually
  run twice — once finding the `backupPrepareCommand` sqlite-staging bug
  (never worked, staged inside restic's own cache dir), once more
  confirming a real restore after the fix. See
  [backup.md](categories/backup.md) and
  [backup-history.md](categories/backup-history.md). What's still open is
  extending backups past cube to the other three hosts
  (**[#130](https://github.com/NireBryce/nixos-configs/issues/130)**).
- **Tailscale Services (`svc:`) — done, 2026-09-11.** Both costs
  originally cited here had real mitigations: the per-service
  admin-console approval is skippable via an `autoApprovers.services`
  policy entry, and the policy file is API-scriptable
  (`flake/scripts/tailscale-acl.py`, `just tailscale-acl`) rather than
  console-only — reviewed as a diff and applied from this repo, same as
  everything else. `svc:grafana`, `svc:git` and `svc:glance` are live,
  each with its own tailnet name and certificate; `nire-cube` is tagged
  `tag:homelab-cube`; `services.tailscale.serve` backs all three on
  `tcp:443` and `tcp:80`; and Caddy's old `/grafana/`/`/git/` path routes
  are retired. URLs are in
  [homelab/reaching-services.md](homelab/reaching-services.md), the build
  in [reverse-proxy](categories/reverse-proxy.md).

  Four traps this turned up, all now written up where they'd be hit rather
  than only here:

  - **Two API endpoint names were wrong in both directions** on the first
    attempt (ACL: `/policy` vs the real `/acl`; vip-services:
    `/by-name/{name}` vs the real `/vip-services/{name}`). Read the
    script's own comments before assuming either path again — and note
    `vip-get` needs the **`svc:`-prefixed** name, or every service 404s
    including ones that exist.
  - **A recorded change is not an applied change.** `svc:glance`'s
    autoApprover sat in this repo's copy of the policy file for a day
    without ever being POSTed, and the Service object was never created at
    all, so the name didn't resolve. `just tailscale-acl diff` is the
    check that catches it.
  - **Creating and updating a Service want different bodies** — an update
    400s without the `addrs` the control plane assigned. Those are
    deliberately not committed (they'd rot on any recreate); `vip-put`
    merges them.
  - **A new Service is not activated by re-running `serve set-config`**
    against an already-standing advertisement. It needs a fresh
    registration: restart `tailscaled`, then `tailscale-serve` after it.

- **Grafana dashboards edited in the UI are not in this repo.** Anything
  under `monitoring`'s `_dashboards/` is provisioned read-only from the
  store; anything created through the web UI lives only in cube's sqlite db.
  That db is now backed up (`/var/lib/grafana` is one of #87's covered
  paths, via the sqlite-staging fix), so a UI-created dashboard survives a
  restore — but it still isn't declared as code, so it still can't survive
  a rebuild that reprovisions `_dashboards/`. "How to add a dashboard that
  survives a rebuild" is now written up:
  [monitoring.md](categories/monitoring.md#adding-a-dashboard-that-survives-a-rebuild)
  — not yet verified against a real UI export, per its own caveat. Now
  tracked as
  **[#190](https://github.com/NireBryce/nixos-configs/issues/190)**.

## Not covered here

`ignore/` at the repo root and `flake/!IGNORE-maybe-useful-chunks/` hold
retired experiments — old library helpers that didn't pan out
(`extendLib.nix`, `findAspectUp.nix`, `findNamespaceUp.nix`,
`recursively-collect-dirnames.nix`, each with its own README noting why it
didn't work). The 2026-08-22 boy-scout cleanup dropped most of `ignore/`'s
cruft and salvaged the one useful thing in it — `root-drift.sh` — out to
`flake/scripts/root-drift.sh`, wired to `just root-drift` (see
[conventions.md](conventions.md)); see recent git history for that commit.
Treat anything still under an `ignore`/`IGNORE`-prefixed path as exactly
that; it's not indexed here on purpose.
