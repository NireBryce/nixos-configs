# Open threads, for agents

_Last modified: 2026-09-12_
_Sibling reviewed: 2026-09-12 — the source's only edit was the live `svc:` list (svc:glance → svc:homepage, issue #291's rollout), nothing this page restates_

Condensed from [open-threads.md](open-threads.md), which keeps the closed
items, the reasoning and the full accounts. Live threads only here.


**Before investigating any symptom: `just threads "<keywords>"`** — it
covers GitHub issues plus `wiki/`, `lessons-learned.md` and
`bugs pending submission/` at once. Skill `investigate-bug`. This page is
not a tracker; this repo's GitHub issues are.

## Open issues worth knowing before you start work

- **#205** — CI can only *evaluate*. `nix flake check + module tree` forces
  each host's toplevel as an evaluation and never builds it, so an input
  bump that evaluates fine and breaks a host stays invisible until
  `just switch` on real hardware (§§36–37). Proposal: build on cube.
  **If it lands, [maintenance-schedule.md](maintenance-schedule.md) item
  10's "Why not sops" reasoning needs rewriting** — it relocates the PAT
  rather than removing it.
- **#130** — extend backups past cube to durandal/tenacity/lysithea.
- **#190** — a Grafana dashboard built in the UI lives only in cube's sqlite
  db. Backed up, but still not declared, so it can't survive a rebuild that
  reprovisions `_dashboards/`.
- **#75** — remove `carapace-completer-read-fix.bash` once ble.sh or carapace
  fix the bug upstream. Check its own "how to check" steps before assuming
  it's still needed.

## Written up, deliberately not filed

`bugs pending submission/` holds three reports against third-party
projects. **Filing outside `NireBryce/nixos-configs` happens only when Elly
says so explicitly, in those words, for that specific report** — never as a
housekeeping pass over this list.

- nixpkgs: vscode ≥ 1.129 patches the wrong ripgrep on Linux (2026-08-11).
- amd-s2idle: sleep residency reported 100× too high (2026-08-12).
- Jovian-NixOS: `amd_iommu=off` blocks s0i3 on non-Deck handhelds with an
  NPU (2026-08-12).

## Undecided questions

- Are the `peripherals` modules (`logitech-g600`/`zsa-moonlander`) still
  wanted on a handheld? Is full desktop package parity still wanted on
  tenacity?
- **QNAP (QuTS hero) has no way to disable SSH password authentication** if
  SSH is ever enabled there. Separate from cube's side of the restic
  connection. Mitigations undecided.
- **Forgejo has no local CI/CD yet** — mirroring `.github/workflows/` onto
  Forgejo Actions hasn't been started.
- CI's lint step re-fetches `nixpkgs#statix nixpkgs#deadnix` on every run
  rather than reusing the flake's own nixpkgs input. Cheap today; worth
  pinning if CI minutes start mattering.
- **Human halves of `-for-agents` pairs, read 2026-09-11** — no decay into
  duplicate siblings (0–5% verbatim overlap across all 19 pairs). Three
  unacted findings: all 19 open with TOC + condensed-version blockquote
  before any orientation prose (line 17–23); `categories/system.md`'s
  subdirectory table is what/where, 5 of 19 rows being the dirname plus
  `.nix`; `disk-formatting.md`'s "Actually formatting the disk" step 3
  describes the disko invocation instead of giving it, and neither half has
  the command.
- Idea placeholders with no content:
  [`../flake/scripts/script-wishlist.md`](<../flake/scripts/script-wishlist.md>),
  and the "things to look into" list at the end of
  [`../flake/doc/notes-and-fixes.md`](<../flake/doc/notes-and-fixes.md>).

## Tailscale Services traps (the `svc:` work, done 2026-09-11)

Each is written up where it'd be hit; repeated here because all four cost
time:

- **Two API endpoint names are counter-intuitive** — ACL is `/acl`, not
  `/policy`; vip-services is `/vip-services/{name}`, not `/by-name/{name}`.
  Read `flake/scripts/tailscale-acl.py`'s own comments. **`vip-get` needs
  the `svc:`-prefixed name**, or every service 404s including real ones.
- **A recorded change is not an applied change.** An autoApprover sat in
  this repo's policy copy for a day un-POSTed, with the Service object never
  created. `just tailscale-acl diff` is the check.
- **Creating and updating a Service want different bodies** — an update 400s
  without the `addrs` the control plane assigned. Not committed (they'd rot
  on a recreate); `vip-put` merges them.
- **A new Service is not activated by re-running `serve set-config`** against
  a standing advertisement. Restart `tailscaled`, then `tailscale-serve`.

## Not indexed here on purpose

Anything under an `ignore`/`IGNORE`-prefixed path (`ignore/`,
`flake/!IGNORE-maybe-useful-chunks/`) is a retired experiment.

## See also

[open-threads.md](open-threads.md) · skill `investigate-bug` · skill
`propose-issue` · [lessons-learned.md](lessons-learned.md)
