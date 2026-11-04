# AGENTS.md

> Working notes for agents, not documentation. Written for a reader with no
> memory between sessions: each rule is here because a session broke it. The
> user has corrected the load-bearing claims. `README.md` is the human entry
> point.
>
> This file is canonical; `CLAUDE.md` is a symlink to it. Skills named below
> are plain markdown at `.agents/skills/<name>/SKILL.md`; any agent can read
> them as files.
>
> This file holds what applies to every session. Path-specific detail lives
> in `.agents/rules/*.md`. Claude Code loads a rule file only when a file
> matching its `paths:` frontmatter is read; other harnesses load none, so
> open the rule file pointed to below before working under its paths.

## Hard rules

Each has been broken here at least once. The section in parentheses has the
reason.

- **Never suggest installing this config wholesale**; it deletes `/root`
  on boot. (Safety)
- **Never decrypt sops output into the conversation.** (Safety)
- **File issues and PRs only in `NireBryce/nixos-configs`**, unless the user
  asks for a specific filing elsewhere. (Working in this repo)
- **"push" means skill `ship`, landing on `experimental`**; `main` is
  promotion-only. (Working)
- **Do work that will branch, commit or check out in its own worktree**,
  not the shared checkout. (Working)
- **`git add` before `nix eval`.** (Working)
- **Public text says what a guard enforces, not what got past it.**
  (Working)
- **Say which rung you reached**, never more. (Before calling it done)
- **A change that makes a wiki page stale fixes it in the same change** —
  skill `wiki-sync`.
- **Trailer `Co-Authored-By: Claude`; prose says "the user".** (Conventions)

## Safety

`WARN-impermanence.nix` (reached through the `impermanence` category)
deletes the `/root` btrfs subvolume in initrd on every boot and needs a
`root-blank` subvolume. **Two of the three NixOS hosts import it and wipe
`/root` on boot: `nire-durandal`, `nire-tenacity`.** `nire-cube` does not
(plain persistent root, no LUKS or impermanence). Check the specific host;
never assume all or none wipe. Read `WARN-impermanence.nix` before changing
anything near it, and take care with
`flake/modules/general-config/impermanence/` and `fileSystems`/`boot` in the
host hardware modules — `.agents/rules/impermanence.md`.

Secrets are sops-nix (`flake/modules/general-config/system/secrets/`).
`secrets.yaml` is encrypted and committed on purpose. `sops -d` prints every
secret in the file: never run it into the conversation or a pipe, and
`2>/dev/null` doesn't stop stdout. To list which secrets exist, run
`just read-sops-names` (names only); decrypting to answer that has leaked
values twice. Skill `secrets-hygiene`; enrolled hosts:
`.agents/rules/secrets.md`.

## State

**Switch/boot state is not recorded in this repo**, because it goes stale.
Whether a host runs what the tree evaluates to can only be answered on the
host: `just baseline`, `just diff-deployed`, or a forced toplevel eval
against `/run/current-system`. Before claiming a change affects a host, find
out what it runs; for a hardware fact, ask (§2). Capture `just baseline`
before switching: once the old generation is collected it can't be
re-derived (§24).

**Don't record what a command or the cited file already answers**: counts of
files, modules, hosts or recipes, line counts, live-state versions (kernel,
Mesa), config values copied from a linked file. They drift silently. Write
the pointer (`the modules under X`, the file, the command) or name the items.
Keep a number only when it is the rule itself, a dated incident or experiment
record, a PR/issue/commit reference, or an interface a user types (a port).
Skill `fact-hygiene` (cat 4); `factcheck docrefs` catches the bare
count-of-files shape. factcheck is young (adopted 2026-10-30): read a
finding before acting on it, and pin the `factcheck` flake input if it
misbehaves.

Roster, class, and which hosts wipe `/root`: `host-config/hosts.nix` (check
it before stating any count) and the table in `wiki/fleet/hosts.md`.
First-boot history: "Confirmed-on-hardware facts" in `wiki/meta/history.md`.

- **Check `hostname` before assuming which machine you're on.** Under Claude
  Code, `.agents/hooks/session-start.sh` injects hostname, branch, worktree,
  dirty count, `core.hooksPath` and the `just agent` helper names. Elsewhere,
  run `just agent where`.
- **ssh to another host over the tailnet as `ts-<x>`, never `nire-<x>`.**
  `nire-<x>` is the hostname (`nire-<x>.local` on the LAN only), and
  tenacity's sshd is tailnet-only. `just reach <x>` tries every name. Rule
  and table: `wiki/fleet/hosts.md`; as code: `tailnet-hosts.nix`.

**Many skills and guards only trigger under the `Bash` tool.** The git,
`just`, nix and secrets guards match it, and skills and recipes are bash
commands. A skill marked `**Needs:** bash-guards` depends on them (skill
`new-skill`). Under another harness, shell or tool those protections are
off: warn the user, and run commands through `just agent guard-check` (skill
`guards-without-hooks`).

## Before you start

- **Find the page for the task.** `wiki/00-INDEX-for-agents.md` routes by
  task. `wiki/agent-lessons-learned.md` lists every past mistake by the
  moment it applies; `just agent lessons <path>` prints the ones for a file
  or area. Bare `just` lists every recipe.
- **A check fails only in CI?** Read the job log for the line that names the
  cause, remove that difference locally (`env -u TERM`, a `PATH` without the
  tool) and watch it fail before fixing (§53).
- **Someone reports a bug?** Run skill `investigate-bug` first (`just threads
  "<keywords>"`), before reproducing anything.
- **Ask "did it work before?" first.** `journalctl --list-boots` plus a grep
  settles regression-vs-always-broken faster than arguing about mechanism.
- **Before hand-building a multi-step pipeline, check `just agent`**, which
  holds agent-written scripts for recurring lookups. To add one: skill
  `agent-scripts`.

## Traps

One line per task. Read the rule (short) or skill (full mechanism) before the
matching task. Under Claude Code and ZCode, the lesson-reminder hook adds each
area's one-line reminder to your context on the first edit or command that
touches it, from `.agents/lessons-map.toml`.

- Writing, renaming or browsing a module: its name is its filename, a rename
  renames it, categories come from folders — skill `new-flake-module`,
  `.agents/rules/flake-modules.md`, `wiki/config-structure/module-files.md`.
- Home Manager shell/dotfiles: `home.file` text concatenates — skill
  `home-manager-dotfiles`, `.agents/rules/home-manager.md`.
- Impermanence, initrd, host hardware: trust `/proc/1/mountinfo` over `lsblk`
  — skill `impermanence-initrd`, `.agents/rules/impermanence.md`.
- Adding or platform-gating a package: Homebrew overlap is never automatic —
  skill `package-platform-support`, `.agents/rules/packages.md`.
- Adding a homelab service — skill `new-homelab-service`,
  `.agents/rules/homelab.md`.
- Any `.nix` edit: `${...}` in a `''` string interpolates, even in a comment;
  freeform `settings` swallow wrong keys — `.agents/rules/nix.md`.
- Scripts and recipes: no Python buried in bash — `.agents/rules/scripts.md`.
- Agent settings, guard hooks, `permissions.allow` —
  `.agents/rules/agent-config.md`.
- Wiki pages: pairs, Quick facts, the siblings check —
  `.agents/rules/wiki.md`.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files,
so a new module silently does not exist. `just modules` checks for untracked
files, and `.agents/hooks/nix-untracked-guard-pretooluse.sh` warns at eval
time.

**Read upstream source instead of guessing at options.** It settled
`perSystem` having no `freeformType` and `home.sessionPath` being `listOf
str`. For third-party packages read the project's current source too:
`handheld-daemon` got a shim for something upstream had already fixed.

**Read the links in a comment before deleting the code it annotates.** A
cited manual page is there because the code depends on it (§11).

**Calibrate severity.** This is a homelab, not production; the repo has gone
six months between commits. Say "this is broken, here is the fix", not
incident language.

**Do any task that will branch, commit or check out in a dedicated `git
worktree`** (skill `use-a-worktree`). Skip it for read-only work, or when the
user says to work in the shared checkout. If git state doesn't match your own
last action, check `git reflog` before concluding anything is broken.

**"push" means the `ship` skill, landing on `experimental`** (the default
branch): branch, PR, one combined ask covering merging and deleting the
branch afterward. If the user names a branch, push directly there, except
`main`: it is the promoted known-good and moves only by PR from
`experimental` after hardware verification. Don't assume a branch; check `git
branch --show-current`.

**File issues and PRs only in `NireBryce/nixos-configs`.** Never file on
another project (nixpkgs, ble.sh, carapace, anything else). The one exception
is the user asking, in their own message, for that specific filing on that
specific project; approving a list of tasks doesn't count, even if one item is
an upstream filing. `propose-issue` files here only. Drafts for other
projects (`_loose-ends/bugs-pending-submission/`,
`wiki/meta/open-threads.md`) are for the user to file; don't work through
them. Security notes are the other exception (next paragraph). A filing here
can still ping another project through GitHub autolinking (`owner/repo#123`
in a title or body): grep for that pattern before filing.

**Security and threat-model analysis goes in the private `elly/infra-notes`
repo on the forge (tailnet-only), never in anything public: PR bodies, commit
messages, wiki pages, code comments, test names or test comments.** Public
text says what a guard or fix enforces and how it was verified, not which
inputs got past it, what they could reach, or which host is exposed. Tests
keep the inputs they check without narrating what they would do. Merged
history through #380, and #435's commit messages, predate this rule and are
not precedent.

**Shape a Bash call to be read in a permission prompt**, which shows the
command string verbatim and wrapped:
- One step per line, not an `&&` chain (`set -e` first if a failure should
  stop the rest).
- `git -C <path>` and absolute paths, not a `cd <path> &&` prefix (a `cd
  "$VAR"` also makes git-guard and just-guard ask).
- Unrelated steps as separate calls.
- A recurring multi-step command is a `just agent` candidate (`show`,
  `where`, `commit` exist): skill `agent-scripts`.

## Before calling it done

Each § is an entry in `wiki/agent-lessons-learned.md`; the full account is
`wiki/agent-lessons-learned/<N>-*.md`.

**Say which rung you reached.** *Evaluates* (`nix eval`, `just check`),
*builds* (`just build`; `nix build --dry-run` gives the plan without
compiling), *runs* (switched and used), and for a setting that renders into a
file, *read the rendered artifact*. Each finds defects the one before cannot.
Treat an undated "verified" as *evaluates*, here and in what you write (§18,
§36).

**Bugs here serialize.** Evaluating a cheap attribute proves nothing: force a
toplevel. §25 records four defects that passed a clean eval and a clean
build, because both stop short of runtime (§37). Each fix can uncover the
next, so a defect count from reading is a lower bound (§6).

**Verify refactors by fingerprint, but not only by fingerprint.** A differing
hash doesn't prove breakage (import order permutes
`environment.systemPackages`). An unchanged one can mean dead code (§43), so
after a change you expected to matter, investigate (§4). Compare values with
`just diff`, including across any module *removal* (removing fish removed the
man index, §7), and make refactored paths run. Model and evaluate a risky
mechanism before betting a refactor on it (§12).

**Read the output, not the status.** `cmd | tail` exits 0 when `cmd` failed;
use `set -o pipefail` or don't pipe (§20). Nix puts the innermost cause last,
so read a trace to the bottom (§21). Before believing a zero, show the query
can return non-zero; before believing a count, know what it counts (§22,
§31). When a tool contradicts you, check your own assumption first (§3).

**A new checker is tested against a case it should catch**, in the same
commit (§1). When an existing check fires on new work, fix its model before
reaching for its escape flag (§23).

**Then** run `just preflight` (what CI runs) and skill `wiki-sync` for any
wiki page the change made stale.

## Conventions

**Read `wiki/config-structure/module-style-guide.md` before writing a new
module.** Its formatting is intentional, not a cleanup target. The other
module conventions (old names on renames, bugs recorded in comments stay,
`elly` hardcoded, `programs.*` first) are in
`.agents/rules/flake-modules.md`.

**Every agent-authored commit carries `Co-Authored-By: <agent>`**: the agent
that wrote it, no model name, no email. An agent can't verify which model is
running, so the trailer records only what it knows. Claude's form is
`Co-Authored-By: Claude`. `.githooks/commit-msg` auto-corrects only the
`Claude <model> <email>` shape, so write any other agent's trailer correctly
the first time.

**Say which kind of module.** A *module file* is a `.nix` file under
`flake/modules/` in the dirs-as-categories shape. A *NixOS module* (or *Home
Manager*, *darwin*) is the value under a class key inside it. A *flake-parts
module* is a plain file such as `hosts.nix` that configures the flake itself.
Never call a module file a "flake-parts module": wrapping a raw NixOS module
as `{ nixos = ...; }` is what makes it a module file
(`wiki/config-structure/module-files.md`).

**In prose, refer to the person as "the user", never by name.** `elly` in an
identifier is the account this config builds; in prose it claims who runs
this repo, which is false for a fork or a fresh session.

**Write plainly.** This applies to everything you write here: this file, rule
files, skills, the wiki, code comments, commit messages, PR bodies. The
readers are agents and contributors who haven't seen the history, and they
need to act on the text.
- Lead with the instruction or fact, then give the reason in one sentence. A
  reader who knows why can handle the case the rule didn't anticipate.
- Use imperatives for instructions and plain declaratives for facts. Define a
  term at first use, and call the same thing by the same name throughout.
- Show a command with its expected output instead of describing it with
  adjectives.
- Cut emphasis and filler: *deliberately, critically, importantly, notably,
  actually, genuinely, simply*, "it's worth noting", "the key insight",
  "turns out". If a point matters, say what breaks when it's ignored.
- Say literally what you mean: no metaphors ("bitten", "footgun", "paper
  over"), no rhetorical questions, no "not X, but Y" framing where a direct
  statement works, and no triplets chosen for rhythm.
- Don't narrate your own process ("I found", "we discovered"). State the
  result; for an incident, one dated line of facts.
- Existing text is fixed when you edit that passage (skill `boyscouting`),
  not in a sweep that buries the real change.

## Commands

`just` recipes live in the root `.justfile` and work from anywhere. Bare
`just` lists them with a one-line summary each; that list is the source of
truth. `just preflight` (wiki-lint + branches-test + check + modules + lint +
the script tests) is what CI runs and is the ship skill's step 0.
`just hm-collisions`, `just root-drift` and `just home-drift` are read-only
and only meaningful on the hardware. `.agents/settings.json` pre-approves a
few read-only recipes; what may join them: `.agents/rules/agent-config.md`.

**With no usable nix** (a Claude Code cloud container has nix but can't fetch
the flake inputs, and has no `just`), the git hooks run
`flake/scripts/offline_checks.py` instead of failing, and say what they left
to CI. `--no-verify` should not be needed. `just preflight-offline` runs the
same set by hand; details in `book/src/agent-checks-and-guards.md`.

`host` derives from `hostname`, falling back to `nire-durandal` off-host.
Put the override **before** the recipe name (`just host=nire-durandal build`);
after it, just reads it as a second recipe name and errors.

To iterate, evaluate directly from `flake/`. `elly` is literal here: it reads
an *evaluated* config, where the attribute name is already resolved.

```sh
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

`build`/`boot`/`switch` go through `flake/scripts/rebuild.sh`, which picks
`nh darwin` or `nh os` off the flake. On a real host, `just build`/`switch`
is a real test, not just evaluation. A NixOS host can't be built from another
machine (no remote builder, no binfmt); `rebuild.sh` says so.

## Architecture

`flake.nix` is a manifest. `(inputs.dirs-as-categories.lib.tree ./modules)`
(an import-tree preset, a flake input) reads every `.nix` file under
`flake/modules/` and fills `flake.modules.<class>.<name>` from them.

**A module file never declares its own name; the filename is the name**,
assigned by `dirs-as-categories`. The file body is an attribute set like
`{ nixos = …; homeManager = …; }`, or a function of `lib`/`inputs` returning
one. Each file's header comment says this, and
`wiki/config-structure/module-files.md` gives the reason. A file under
`flake/modules/` not in that shape (`hosts.nix`, `checks.nix`) is a plain
flake-parts module.

**Membership comes from the directory.** A folder with a subfolder holding
modules is a category and includes every module beneath it; hosts list
categories by name in `includes.<class>`. Categories are how shared things
stay optional (no `mkEnableOption`). Areas: `general-config/` (incl.
`macos/` for darwin), `hardware-config/`, `homelab-config/` (self-hosted
services), `host-config/`, `packages-config/`, `users-config/`. Detail:
`.agents/rules/flake-modules.md`. Host roster: `host-config/hosts.nix` (its
comments cover naming, the forge-runner guest, removed hosts); don't restate
it.

**Home Manager is NixOS-integrated**: no `homeConfigurations`, no separate
home switch; `just switch` applies both (`.agents/rules/home-manager.md`).
`elly-home-manager` is shared verbatim by every host, including
`nire-lysithea`, so everything in it must work on darwin.

## Docs

Start at `wiki/00-INDEX-for-agents.md`, which routes by task. A long wiki page
is either a pair (read the `-for-agents.md` half) or opens with `## Quick
facts` (read that first). Edit both halves of a pair in the same change:
`factcheck siblings` fails otherwise. The mechanics are in
`.agents/rules/wiki.md`, which Claude Code loads when a `wiki/**` file is read.

A change that makes a wiki page stale corrects it in the same change (skill
`wiki-sync`; `just wiki-lint` checks the mechanical claims).
`wiki/agent-lessons-learned.md` lists every past mistake as one line. A new
lesson goes in its Home page as well as that index, and § numbers are never
renumbered.
