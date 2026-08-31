# Open threads

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

- **[#87 — no backups anywhere in the fleet; decide a scheme for cube's
  service state](https://github.com/NireBryce/nixos-configs/issues/87)** —
  open, filed 2026-08-24. Nothing in `flake/` configures any backup tool at
  all (verified by grep, not assumed), while `nire-cube` now holds a git
  forge, a metrics db and a shortlink db that nothing else has a copy of. A
  QNAP NAS on the network makes this mostly a matter of picking a tool;
  the issue carries the restic-over-SFTP sketch, the sqlite-consistency
  problem, and the four things that need deciding rather than defaulting.
  **Done means a restore actually performed**, not a green timer.
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

- **[`../flake/modules/nire/hardware/todo.md`](<../flake/modules/nire/hardware/todo.md>)**
  — eventually give the overarching `dirsAsCategory` mechanism flags so it
  can auto-import based on system type.
- **[`../flake/modules/nirePackages/idea.md`](<../flake/modules/nirePackages/idea.md>)**
  — consider migrating more unconfigured packages from Home Manager to
  plain `nix`. Also noted on [architecture.md](architecture.md).
- **[`../flake/scripts/mkPkgModule.md`](<../flake/scripts/mkPkgModule.md>)**
  — a ready-but-unused generator for the ~70 single-package module files
  under `nirePackages/`; a trailhead with the adoption cost spelled out, not
  a plan anyone's committed to. Also on [architecture.md](architecture.md).
- **[`../flake/scripts/script-wishlist.md`](<../flake/scripts/script-wishlist.md>)**
  — bare headings only (`vicinae`, `just`, `espanso`, `other`), no content
  yet. A placeholder for future script ideas, not current work.
- **[`../claude cave/2026-08-09 things to look into eventually.md`](<../claude cave/2026-08-09 things to look into eventually.md>)**
  — a security-hardening reference link, plus two questions rescued from a
  deleted handoff doc (are `logitech-g600`/`zsa-moonlander` peripheral
  modules still wanted on a handheld; is full desktop package parity still
  wanted on tenacity). Neither has been decided.
- **[`../claude cave/2026-08-24-evaluation-self-hosted-booking.md`](<../claude cave/2026-08-24-evaluation-self-hosted-booking.md>)**
  — Easy!Appointments vs LibreBooking, compared 2026-08-24 and then
  explicitly not pursued. Nothing built, no host picked. Records which of
  the two fits which problem (they aren't competitors — one books a
  person's time, the other books a *thing*), that **neither is in nixpkgs
  and neither has a NixOS module**, and the one design problem that would
  actually need solving if it restarts: both are PHP apps wanting a
  writable install dir, so podman-vs-hand-written-module is the unanswered
  first question. Also corrects a from-memory claim about Cal.com's
  license.
- **[`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>)**
  ends with a "things to look into" list — MyNixOS, nixpkgs-wayland,
  nix-direnv, haumea, flakelight, flake-utils(-plus), devshell, devbox,
  devenv, nixos-shell, nix-index, nix-prefetch — and an unanswered "learn
  what `outputs @ inputs:` means and figure out specialArgs" note. Also
  covered from the fix-snippet angle on [conventions.md](conventions.md).

`nire-llm-sandbox`'s three runtime-verified `VMs/_lib/libvirt-vm.nix` fixes
(default network never started, a nonexistent `virsh` flag, a missing fixed
domain UUID) used to be recorded here; the VM itself was removed 2026-08-28
— see [history.md](history.md) and `claude cave/lessons-learned.md` §40 for
that detail now.

## Left open by the cube service stack, 2026-08-24

Four things the reverse-proxy/glance work knowingly did not do. None is a
bug; each is a decision someone might otherwise re-litigate from scratch.

- **`nire-cube` is running a config activated from `~/nixos-caddy-test/`**, a
  plain rsync of a working tree, while its real checkout at
  `~/nixos-configs` sits several commits behind `main`. The running system is
  byte-identical to what `main` evaluates to, so this is bookkeeping rather
  than drift — but the next person to `just switch` from `~/nixos-configs`
  should `git pull` first, and the test directory can be deleted once they
  have. Sync-and-build-over-ssh exists because a darwin session cannot build
  an `x86_64-linux` toplevel; see the `new-homelab-service` skill.
- **Nothing backs up `/var/lib/forgejo`** — or anything else on cube. Repos,
  the sqlite database, and Forgejo's self-generated secrets all live there
  with exactly one copy. **Now tracked as
  [#87](https://github.com/NireBryce/nixos-configs/issues/87)**, which covers
  the whole fleet rather than just the forge; documented at
  [homelab/forgejo.md](homelab/forgejo.md) so nobody mistakes the forge for
  durable storage in the meantime. **A [backup](categories/backup.md)
  category landed 2026-08-28** implementing #87's scheme — doesn't move any
  other host, switched and running on cube as of 2026-08-30. Shipped as
  restic over a local-path NFS repo, which failed for real (an export ACL
  the QNAP never granted cube); as of 2026-08-31 it's SFTP instead, #87's
  original plan, now that SSH works on the QNAP. Blocked on two sops
  secrets nobody with decrypt access has set yet and still no anti-deletion
  snapshot configured. Still exactly one copy of everything until both
  land and a restore is actually performed.
- **Tailscale Services (`svc:`) were weighed and deferred.** They would give
  each service its own tailnet DNS name (`https://grafana/` rather than a
  path prefix), which removes the whole prefix-handling problem
  [reverse-proxy](categories/reverse-proxy.md) documents, and they'd allow
  per-service ACLs. The cost is a per-service approval step in the Tailscale
  admin console, and state that lives in `tailscaled` rather than in the Nix
  store. Path routing under one hostname won on "everything stays in the
  repo". The other scaling path, if the service count makes prefixes
  annoying, is a real domain with split DNS and a wildcard certificate.
- **Grafana dashboards edited in the UI are not in this repo.** Anything
  under `monitoring`'s `_dashboards/` is provisioned read-only from the
  store; anything created through the web UI lives only in cube's sqlite db,
  which is not backed up either. Writing up "how to add a dashboard that
  survives a rebuild" is the missing piece.

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
