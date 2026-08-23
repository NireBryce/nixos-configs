# Traps & skills

[`../CLAUDE.md`](../CLAUDE.md)'s own "Traps" section carries a one-line
summary of each; the full mechanism, code, and worked examples live in the
matching skill, loaded only when the matching task comes up so it doesn't
cost context every session regardless of what's being worked on. Read the
skill before doing the matching task rather than re-deriving from the
one-liner.

| Task | Skill |
|---|---|
| Writing/renaming a flake-parts module | `.claude/skills/new-flake-module/SKILL.md` |
| Editing HM shell/dotfile modules | `.claude/skills/home-manager-dotfiles/SKILL.md` |
| Editing impermanence or initrd | `.claude/skills/impermanence-initrd/SKILL.md` |
| Adding/platform-gating a package | `.claude/skills/nirepackages-platform-support/SKILL.md` |
| Adding a new host | `.claude/skills/new-host-config/SKILL.md` |
| Building a NixOS VM image / wiring a libvirt guest | `.claude/skills/nixos-vm-images/SKILL.md` |
| Landing work on `main` | `.claude/skills/ship/SKILL.md` |

See [architecture.md](architecture.md) and
[impermanence-and-secrets.md](impermanence-and-secrets.md) for where each of
these fits into the bigger picture; this page is just the index.

## Two traps general enough to stay inline in `CLAUDE.md` rather than a skill

- `${...}` inside a Nix `''` string is interpolation, even inside what reads
  like a comment — escape as `''${...}` or reword. General enough (any `''`
  string) that it isn't specific to one kind of module.
- **`git add` before `nix eval`** — flakes in a git repo ignore untracked
  files, so a new module can silently not exist yet as far as evaluation is
  concerned.

## A trap that points at the wiki instead of a skill

- **Debugging "can't reach a host by tailscale name"** — no skill for this
  one; the full mechanism lives in `networking/tailscale.nix`'s own header
  and is indexed at [categories/system.md](categories/system.md)'s
  "Tailscale" section instead. Two traps, neither a bug in this repo's nix
  config: Tailscale device names don't match `networking.hostName`
  (`nire-cube` the host is `ts-cube` on the tailnet), and a tailnet ACL can
  silently block all peer-to-peer traffic while every local firewall
  setting is correct — that one's fixed in the admin console, not here.

## Style

- **[`../claude cave/claude-style-guide.md`](<../claude cave/claude-style-guide.md>)**
  — conventions for `flake/modules/`: aligned-`=` columns are intentional,
  `nix fmt` is deliberately not wired up because it would flatten them.
  Counts in it are dated 2026-08-08 and checkable against the tree rather
  than asserted as current.
- **Conventions section of [`../CLAUDE.md`](../CLAUDE.md)** — commit
  trailer wording (and why it deliberately omits a model name — see the
  section for the reasoning), namespacing (`nire`/`nireHost`/`nireUser`/
  `nirePackages`), the "say what it was" rule for renames, the "don't bury
  Python in bash" rule with its two ways out.
