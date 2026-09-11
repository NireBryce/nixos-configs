# Traps & skills

_Last modified: 2026-09-11_

## Contents

- [Two traps general enough to stay inline in `CLAUDE.md` rather than a skill](#two-traps-general-enough-to-stay-inline-in-claudemd-rather-than-a-skill)
- [A trap worth knowing before it's needed](#a-trap-worth-knowing-before-its-needed)
- [A trap that points at the wiki instead of a skill](#a-trap-that-points-at-the-wiki-instead-of-a-skill)
- [Style](#style)

[`../CLAUDE.md`](../CLAUDE.md)'s own "Traps" section carries a one-line
summary of each; the full mechanism, code, and worked examples live in the
matching skill, loaded only when the matching task comes up so it doesn't
cost context every session regardless of what's being worked on. Read the
skill before doing the matching task rather than re-deriving from the
one-liner.

| Task | Skill |
|---|---|
| Writing/renaming a flake-parts module | `.agents/skills/new-flake-module/SKILL.md` |
| Editing HM shell/dotfile modules | `.agents/skills/home-manager-dotfiles/SKILL.md` |
| Editing impermanence or initrd | `.agents/skills/impermanence-initrd/SKILL.md` |
| Adding/platform-gating a package | `.agents/skills/nirepackages-platform-support/SKILL.md` |
| Adding a new host | `.agents/skills/new-host-config/SKILL.md` |
| Adding a homelab service (port, proxy route, verification) | `.agents/skills/new-homelab-service/SKILL.md` |
| Giving a service its own Tailscale Services (`svc:`) hostname | `.agents/skills/new-tailscale-service/SKILL.md` |
| Landing work on `experimental` | `.agents/skills/ship/SKILL.md` |
| Filing a bug noticed while doing something else | `.agents/skills/propose-issue/SKILL.md` |
| Checking whether a change left a `wiki/` page stale | `.agents/skills/wiki-sync/SKILL.md` |
| Tightening wiki/skill/AGENTS prose for conciseness | `.agents/skills/trim-docs/SKILL.md` |
| Compressing a module's history section | `.agents/skills/trim-history/SKILL.md` |
| Writing a new skill | `.agents/skills/new-skill/SKILL.md` |
| Starting a task that will branch, commit, or check out | `.agents/skills/use-a-worktree/SKILL.md` |

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

## A trap worth knowing before it's needed

- **Two apps behind the same reverse proxy can need opposite prefix
  handling.** Grafana serves *under* its path prefix (`serve_from_sub_path`)
  and Caddy must leave the prefix on; Forgejo always serves at `/` no matter
  what its `ROOT_URL` says, and Caddy must strip it. Both spellings are valid
  Caddy, both build, and the wrong one is a 404 on every page of the affected
  app. It cost a switch on 2026-08-24 —
  [lessons-learned.md](lessons-learned.md) #41, with the
  routing detail in [reverse-proxy](categories/reverse-proxy.md). The
  `new-homelab-service` skill has the two-`curl` test that settles it in
  seconds.

- **Adding an explicit `tls` directive to one Caddy vhost changes the
  issuer for every other vhost.** The Caddyfile adapter emits automation
  policies for *all* sites as soon as *any* site declares `tls`, and Caddy's
  Tailscale-certificate auto-detection only runs for names that have no
  policy — so `tls internal` on three bare-name redirects silently pointed
  four unrelated `.ts.net` vhosts at public Let's Encrypt, which can never
  issue for a tailnet name. Two days of `SSL_ERROR_INTERNAL_ERROR_ALERT` on
  names no commit had touched, 2026-09-08. Eval, build, `just modules` and
  `caddy adapt` all pass — the config is valid, it just means something
  else; only a real handshake finds it. The general shape, and the questions
  to ask before adding an explicit setting anywhere:
  [lessons-learned.md](lessons-learned.md) §47.

## A trap that points at the wiki instead of a skill

- **Debugging "can't reach a host by tailscale name"** — no skill for this
  one; the full mechanism (three traps: names don't match `networking.
  hostName`, a tailnet ACL can silently block peer traffic, and a name
  that won't resolve at all means check Tailscale on the client, not the
  name) lives in `networking/tailscale.nix`'s own header, indexed at
  [categories/system.md](categories/system.md)'s "Tailscale" section. `just
  reach <host>` (`flake/scripts/reach-host.sh`) is the automated fix for
  the third one.

## Style

- **[module-style-guide.md](module-style-guide.md)**
  — conventions for `flake/modules/`: aligned-`=` columns are intentional,
  `nix fmt` is deliberately not wired up because it would flatten them.
  Counts in it are dated 2026-08-08 and checkable against the tree rather
  than asserted as current.
- **Conventions section of [`../CLAUDE.md`](../CLAUDE.md)** — commit
  trailer wording (and why it deliberately omits a model name — see the
  section for the reasoning), namespacing (`nire`/`nireHost`/`nireUser`/
  `nirePackages`), the "say what it was" rule for renames, the "don't bury
  Python in bash" rule with its two ways out.
