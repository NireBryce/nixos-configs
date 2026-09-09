# 03 — Conventions and style

_As of: 2026-09-08. Primary sources (canonical, this page only summarizes):
`wiki/module-style-guide.md`, `wiki/conventions.md`, `wiki/styleguide.md`,
`AGENTS.md` § Conventions, `.claude/skills/ship/SKILL.md`._

## Nix code style (the parts a newcomer gets wrong first)

- **Brackets open on the same line** as whatever causes them. The one
  purely aesthetic rule.
- **Four spaces**, everywhere. Module bodies sit one level deeper than
  strictly necessary — left over from moving `flake.modules` out of
  `perSystem` without reflowing, and deliberately not fixed because
  reindenting risks the `''` strings in shell modules.
- **No formatter, on purpose.** `nix fmt`/treefmt/`nixd` formatting are all
  disabled (`.vscode/settings.json` does it twice, with comments; the flake
  drops the `formatter` output entirely). Reason: a formatter flattens the
  **aligned `=` columns** used for runs of related assignments. If treefmt
  is ever added, the style guide requires `flakeCheck = false`.
- **The module header** (every file): the module name is derived from the
  filename, never repeated as a literal. Argument placement is load-bearing:
  `lib`/`inputs` in the outer flake-parts lambda; `pkgs`/`config` in the
  inner one. Outer `pkgs` is perSystem's — no `allowUnfree` — and outer
  `config` is the flake-parts tree, not the NOS one. Both mistakes are
  silent.
- **`# # description = "..."`** — a commented-out one-liner as the first
  line of the module body. It is a comment because the module system has no
  per-module metadata (verified upstream, not assumed — see the style
  guide's "Why it is a comment"). A typed registry alternative was
  considered and **declined**; do not "upgrade" it without a reason beyond
  tidiness.
- **Rationale comments live inside the module body**, next to the option
  they explain — never as a header block above the lambda. One exception to
  remember: `#` inside a `''` string is shell text, and once shipped
  fourteen lines of maintenance notes into a real `~/.zshrc`.
- **`with pkgs; [ ... ]`** for package lists, one per line.
- **`${...}` inside a `''` string is interpolation.** Writing
  `${terminfo[khome]}` in an intended comment is an eval error; escape as
  `''${...}`.
- A bare `{ ... }:` inner lambda is sometimes a deliberate readability
  signal ("this value is a module"), accepted into `lint-baseline.json`
  against statix W10 — don't lint-pass it into `_:`.

## Naming

- Namespaces: `nire` (default; "start broad, go narrow" —
  `flake/doc/notes-and-fixes.md`), `nireHost`, `nireUser`, `nirePackages`.
- Hosts: `nire-<name>`; config modules `<name>-configuration.nix`.
- Package leaves: directory name = module filename (`ripgrep/ripgrep.nix`).
- `WARN-` prefix marks modules with deliberately loud, destructive or
  guard-rail behavior (`WARN-impermanence.nix`, `WARN-password-required.nix`).
- Renames: **when the old name becomes ungreppable, say what it was** in a
  comment on the declaration (`boot-durandal.nix`,
  `enable-home-manager.nix` are the worked examples).

## Comments and history

- **A bug recorded in a comment stays in the file.** Nobody reads git log.
  If a change strands the comment, move it to a `## history` section at the
  bottom, still written to stand alone. (`WARN-impermanence.nix`,
  `boot-durandal.nix`, `sops.nix` all carry these.)
- The tree's long inline comments are load-bearing documentation, not
  chatter — the flake.nix formatter comment and the hosts.nix allowUnfree
  comment are the model: mechanism, evidence, date.
- Docs pages (wiki) carry `_Last modified: YYYY-MM-DD_` and a generated
  `## Contents`; `wiki-lint` enforces both mechanically.

## Git and commit conventions

- Conventional-Commit prefix on the **first line only** (`feat:`, `fix:`,
  `docs:`, `ci:`, `chore:`); the body is this repo's own narrative
  what/why/verified style, not Conventional Commits.
- **Write the message to a file and `git commit -F <file>`** — backticks and
  `$(...)` written inline get executed by the shell first (hit 2026-08-30).
- **Explicit pathspec always** (`git commit -F msg -- <paths>`); `--amend`
  commits whatever is staged *now*, which has swept unrelated files twice.
- Multi-commit changes are ordered so **each commit is green** (checked in a
  throwaway worktree — ship skill §0).
- **Provenance trailer on every agent-authored commit**:
  `Co-Authored-By: <agent>` — agent name only, no model, no email. Agents
  cannot verify which model they are (the log holds dozens of wrong
  labels), so the trailer records what it knows. `.githooks/commit-msg`
  auto-corrects only the `Claude <model> <email>` shape; other agents must
  form their trailer correctly at write time.
- Branch names: `feat/`, `fix/`, `docs/…` prefixes, matching the commit
  prefix.

## Docs conventions

- **Anti-duplication**: wiki pages link; they don't restate (its
  `styleguide.md` makes this a rule, with a history section about the
  removal of a hand-maintained Members column that kept rotting). Whoever
  makes a page stale fixes it in the same change (`just wiki-lint` is the
  backstop).
- Facts that could rot are written as dated snapshots or made checkable.
  `AGENTS.md`'s State section and `wiki/hosts.md` both refuse to record
  switch state at all.
- Skill files (`.claude/skills/*/SKILL.md`) hold the *long version of
  traps*; `AGENTS.md` § Traps holds the short version + pointer. The
  pattern: a mistake that has actually happened becomes either a skill
  (judgment required), a hook (mechanically checkable), or a lint rule
  (countable).

## The trap catalogue (short form; each has a skill or a §)

| Trap | One line | Where |
|---|---|---|
| Impermanence wipes `/root` | Two of three NixOS hosts; check the specific host | skill `impermanence-initrd` |
| Shell's mount view lies | Use `/proc/1/mountinfo`, `/dev/disk/by-uuid/` | same |
| `home.file`/`sessionPath` concat | Two modules writing "one" file double it silently | skill `home-manager-dotfiles` |
| Reading generated dotfiles back | Wrong attr name returns empty; `.source` vs `.text` | same |
| Untracked files invisible to flakes | `git add` before `nix eval`; `just modules` backstops | AGENTS.md |
| Bugs serialize | Cheap-attribute eval proves nothing; force a toplevel | AGENTS.md, §25/§37 |
| Outer `pkgs`/`config` shadow | perSystem pkgs drops `allowUnfree` | style guide |
| Module name = filename | Renames drop modules; same names merge | skill `new-flake-module` |
| `cp` is aliased `cp -i` | Non-interactive it exits 0 *without copying* | ship skill |
| Tailscale device ≠ hostname | `ts-cube` is the device name | tailscale.nix, `.justfile` |
| `''${...}` | Interpolation inside `''` strings | AGENTS.md |

## Recommendations

- **R4 (optional) — add a `.editorconfig`.** The repo encodes indent and
  width rules in prose and `.vscode/settings.json` only; a root
  `.editorconfig` (`indent_style = space`, `indent_size = 4`,
  `insert_final_newline`, trailing whitespace) would carry them to every
  other editor and to GitHub's rendering without importing a formatter.
  It contradicts nothing — it is not `nix fmt`.
- The style-guide counts issue is R3, in [02](02-architecture.md).
