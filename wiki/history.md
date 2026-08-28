# History & lessons learned

## This repo's own history

- **[`../claude cave/lessons-learned.md`](<../claude cave/lessons-learned.md>)**
  — "Written by Claude Code, for Claude Code, and largely a record of its
  own mistakes." The main one. §§1–18 the den → flake-parts port, §§19–24
  the first session on real hardware, §§25–31 after it first booted, §§32–38
  later work on already-booted or newly-added hosts (auto-allocators can't
  see manually pinned ranges; a removed nixpkgs option asserts rather than
  being ignored; a module name that collides with its own category *merges*
  invisibly, three separate times; a well-typed value can still be
  semantically wrong, so build the artifact and read it back; some bugs need
  real filesystem/daemon state that only exists once an actual `switch` runs
  — invisible to evaluation *and* to reading back a built artifact; a fix
  scoped to the caller that needs it beats a general one). `CLAUDE.md` has
  the rules this produced; this has the scar tissue behind them.
- **[`../claude cave/lessons-learned-impermanence-stage1-migration.md`](<../claude cave/lessons-learned-impermanence-stage1-migration.md>)**
  — the stage-1 impermanence migration specifically. Covered from the
  impermanence angle on [impermanence-and-secrets.md](impermanence-and-secrets.md).
- **[`../claude cave/2026-08-09 things to look into eventually.md`](<../claude cave/2026-08-09 things to look into eventually.md>)**
  — open questions rescued from a deleted `HANDOFF-tenacity.md`, partially
  answered since (handheld stack — Jovian Steam autostart, decky-loader,
  handheld-daemon/adjustor — does work; recorded in `jovian.nix`). Also
  listed on [open-threads.md](open-threads.md).
- The `old-`/`old-historical-`-prefixed planning and handoff artifacts (the
  den→flake-parts port plan, the durandal/lysithea handoff, and tenacity's
  plan/prompt files) were removed 2026-08-26, their useful content already
  superseded by `lessons-learned.md`, `CLAUDE.md`'s State section, and this
  page. Still in git history if one of them is ever needed again.
- `nire-lego` (a handheld, Legion Go, added to config but never built or
  switched) and `nire-installer` (the generic live-USB installer image,
  generalized 2026-08-22 from what originally installed `nire-testbed`) were
  both removed 2026-08-27, along with their `nireHost/lego/`,
  `nireHost/lego-configuration.nix`, and `nireHost/installer/` files and
  `hosts.nix` entries. Neither had ever run against real hardware. The
  live-USB mechanism itself (embedded flake, patched Calamares, unattended
  `nixos-install`) isn't disproven or abandoned, just not carried in this
  tree any more — its last version is in git history if it's ever needed
  again, same as `nire-testbed`'s.
- `nire-llm-sandbox` (a `nixosConfigurations` entry that built a qcow2 image
  and ran it persistently as a libvirt VM on `nire-cube`, sandboxing an LLM
  coding agent away from the real host) was removed 2026-08-28, along with
  its `nireHost/llm-sandbox/` files, its `hosts.nix` entry, and
  `virtualization-cube.nix` (the cube-side wiring that defined the guest
  domain). It had been confirmed booted and staying up on real hardware as
  of 2026-08-24 — see the "Confirmed-on-hardware facts" section below for
  what that confirmation actually checked, and
  [`../claude cave/lessons-learned.md`](<../claude cave/lessons-learned.md>)
  §40 for the three runtime-only bugs its first switch hit. The generic
  generator it ran on, `VMs/_lib/libvirt-vm.nix`, is kept as unexercised
  reusable infrastructure — see [virtualization](categories/virtualization.md);
  the sandbox's own last full config is in git history if a VM like it is
  wanted again.

## Confirmed-on-hardware facts, and how they were confirmed

Both durandal's and tenacity's first-boot `/root` rollbacks were confirmed
by reading the journal and checking the btrfs subvolid actually changed
(607 → 622 for tenacity; 1426 deleted / 1431 mounted for durandal) — not
merely by the machine coming back up. See
[`../CLAUDE.md`](../CLAUDE.md)'s State section for the dates and
generations. This is the concrete example behind the repo's own
"treat an undated 'verified' as *evaluates*" and "ask 'did it work before?'
first, via `journalctl --list-boots`" rules.

## The sibling branch

- **`git show origin/flake-parts:SESSION-HANDOFF.md`** — that branch's own
  notes on dead ends and decisions not to silently relitigate. Needs the
  `origin/` prefix; there's no local `flake-parts` branch in a normal
  checkout.
- **`git show origin/flake-parts:linux-flake/flake-parts-reference.md`** —
  flake-parts machinery reference with upstream source backing each claim.
  That branch never went through this one's `linux-flake/` → `flake/`
  rename, so the old path is correct *there* specifically.
