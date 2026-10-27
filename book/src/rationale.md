# Why it is built this way

This chapter collects the design decisions that were deliberate choices,
not defaults, together with the dead ends that led to them. Each dead end is
described by the symptom that identified it. Read it before you "tidy"
something that looks odd. Most of the odd-looking parts of this tree were
chosen on purpose, and the repo treats silently re-deciding them as worse
than either answer.

## A note on the sources

The git history in this clone is shallow. The oldest commit, `8d4f570`
(2026-10-19), is a graft that holds the whole earlier tree. Commits that the
docs cite from before it (`0c0b5f0`, `5808bfe2`, the deleted `flake-parts`
branch tip `cf9aea42`) are not objects in this clone. For anything earlier
than 2026-10-19, this chapter therefore relies on the dated working notes in
`flake/doc/` and `wiki/`, not on `git log`. To check one of those older
claims against a full history, use the `git-archaeology` skill
(`.agents/skills/git-archaeology/SKILL.md`) in a clone that has it.

Source: `git rev-parse --is-shallow-repository` (true);
`git cat-file -t 0c0b5f0` (not a valid object).

## Decision: flake-parts, for one option

**Choice.** The flake is built with flake-parts. The reason given is one
option, `flake.modules.<class>.<name>`, which `flakeModules.modules`
declares as a `deferredModule`. With it, one file can hold a NixOS module
and a Home Manager module for the same feature as sibling attributes. The
alternative is two files tied together by nothing but a shared filename.
The worked example is the old `nixd.nix`, which installed `nixd` both
system-wide and in Home Manager from one file.

**What is deliberately not used.** The rationale note lists, from grep,
which flake-parts features are used and which are not. Unused:
`moduleWithSystem`, `debug`, overlay or `legacyPackages` composition, and
any bundled flake module other than `modules` and `touchup`. `perSystem` is
used for checks and the one dev shell, and `withSystem` appears once.

Source: `flake/doc/flake-parts-rationale.md`;
[flake-parts.md](../../wiki/config-structure/flake-parts.md).

## Decision: hosts build their own `pkgs`

**Choice.** `hosts.nix` uses `withSystem` only to get `self'` and `inputs'`
into `specialArgs`. It deliberately does **not** pass perSystem's `pkgs` to
the hosts.

**Why.** perSystem's default `pkgs` is `legacyPackages.<system>` with no
`nixpkgs.config` applied. Using it would silently drop `allowUnfree`, and
these hosts install unfree packages. The accepted cost is a second nixpkgs
instantiation.

Source: `flake/modules/host-config/hosts.nix` (comments above `mkHost`);
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"`withSystem`".

## Decision: membership by directory, not per-module opt-in

**Choice.** A module belongs to the category of the folder it sits in. The
`dirsAsCategory.md` note dates the choice to commit `0c0b5f0` and says it
was repaired rather than replaced during the flake-parts port.

**The alternative, and what it costs.** The sibling `flake-parts` branch
used per-module opt-in, where each module declares which aggregates it joins.
That approach has real advantages: directory and membership come apart, a
module can join several roles, and the result is greppable. The note lists
its costs:

- An opt-in line per module.
- No file that shows a roster.
- **A new silent failure.** Leave out the opt-in line and the module is
  valid, evaluates cleanly, and installs nothing. No evaluation can ever
  report this.

Categories cannot fail that way, because membership is automatic.

**The symptom that justified checking first.** Before the pattern was
adopted, someone built a throwaway `mkFlake` with two modules that each set
the same aggregate's `imports`, and confirmed that both definitions
survived. The port notes say that experiment is why the pattern was adopted
at all, instead of being assumed to work (§12 in
[agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)).

**A documented way back.** `flake/doc/dirsAsCategory.md` keeps a "How to
convert" section. This follows a pattern the user has chosen three times:
when a choice is close, keep a documented escape hatch instead of re-arguing
it (§13).

Source: `flake/doc/dirsAsCategory.md`, "What the alternative is";
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Dead ends"; `wiki/agent-lessons-learned/13-reversibility-for-decision.md`.

## Dead end: hand-written module names and category shims

**What it was.** Until 2026-10-16, every module computed its own name from
`__curPos.file`. Every category folder held an identical copy of a shim,
`dirsAsCategory.nix`, which called a shared collector in `_lib/`.

**The symptoms.**

- A module whose hand-written name differed from its filename dropped out
  of every category, and nothing reported an error.
- Shims that should have been byte-identical drifted. Hashing found copies
  that differed by a comment word.
- A renamed shim once made nested categories collect a phantom module
  called `dirsAsCategory`. The class filter hid it.

**What replaced it.** The `dirs-as-categories` flake input. It takes the
name from the file and works out categories from the shape of the tree, so
no file states either. Same-named modules now fail evaluation instead of
merging. The move was checked by comparing every host's toplevel `drvPath`,
and the fingerprints, before and after.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Why the name comes from the filename", "Why categories need no shim", "How
the move was checked"; `flake/doc/dirsAsCategory.md`, "Things that are
load-bearing" and its History banner.

## Dead end: same-named modules merging silently

**Symptom.** Importing the `boot` category applied durandal's bootloader,
because durandal's `boot.nix` and the `general-config/boot/` category shared
the name `boot` and merged. A second near-miss had no visible symptom at
all. A `virtualization/` category holding a `virtualization.nix` would have
merged two halves that were both libvirt config, so everything would still
have worked until someone imported the category expecting only the
category.

**Lesson.** A merge is visible only when the two halves disagree. Give the
file the specific name (`libvirt.nix`, `podman.nix`) and leave the general
name to the category. Evaluation now enforces this.

Source: `wiki/agent-lessons-learned/34-collision-where-both-halves-work.md`;
`.agents/skills/new-flake-module/SKILL.md`, "Names share one namespace".

## Decision: Home Manager integrated into NixOS

**Choice.** Home Manager is wired in from the system side, with
`useGlobalPkgs` and `useUserPackages`. It was chosen over standalone, and
over keeping both.

**What it bought.** One switch instead of two, one nixpkgs instantiation,
and a home config that cannot drift out of sync with its system.

**What it cost.** Home modules may not set `nixpkgs.*`; doing so is an
error, not a no-op. Activation runs as a systemd unit with a minimal `PATH`,
and the home config can't be switched on its own.

`flake/doc/trailhead-home-manager-standalone.md` is the documented way back.
For more detail, see [Wiring a user and Home Manager](users-and-home-manager.md).

Source: `flake/doc/trailhead-home-manager-standalone.md`, "What integrated
actually bought and cost";
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults".

## Decision: package parity across hosts

**Choice.** No role split. The handheld gets the full desktop GUI set
(`vscode`, `gimp`, `libre-office`, `zoom`, …) on purpose. A split was
offered and declined, and the structure was left able to split later.

**Consequence.** `packages-config/` has one file per package (the "full
per-file dendritic conversion"). The boilerplate was accepted. The old role
names `base` / `desktop` / `handheld` have been superseded by categories.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults"; comment above the package categories in
`flake/modules/host-config/tenacity-configuration.nix`.

## Decision: derived platform support, never derived Homebrew overlap

**Choice.** One module, `drop-unsupported-packages.nix`, filters
`home.packages` by `meta.platforms`, on darwin only, and warns by name about
each package it drops. It replaced hand-written `isDarwin` guards that were
all correct but each restated a fact nixpkgs already knows. On Linux the
filter does nothing on purpose: a package that can't build there is a
mistake, and it should stay a loud error.

**What it deliberately does not do.** It does not catch `meta.broken`. It
does not detect Homebrew overlap either; `just available --duplicates` is
the tool for that. [Adding a package](adding-a-package.md) walks through
it.

Source: header of
`flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`;
`.agents/skills/package-platform-support/SKILL.md`.

## Decision: `nix fmt` is not wired up

**Choice.** The aligned `=` columns in the modules are deliberate. A
formatter would flatten them, so `treefmt` is absent and the flake's
`formatter` output is turned off with `touchup`.

**Symptom that forced the `touchup` line.** CI's first real run failed
`nix flake check` with "flake-parts could not determine statically that no
formatter is defined". The error reproduced on a fresh clone too. It had
been missed locally partly because the check was piped through `tail`,
which reports the exit status of `tail`, not of the check (§20).

Source: comment on `touchup` in `flake/flake.nix`;
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md),
"Formatting".

## Decision: impermanence on two hosts, not all

**Choice.** `nire-durandal` and `nire-tenacity` wipe `/root` on every boot,
so that any state that matters has to be declared in the repo. Forgetting
something fails loudly the next day instead of silently years later.
`nire-cube` was installed by hand with a plain root and opts out. Its entry
point says so and explains how the checks opt out with it.

Source: `WARN-impermanence.nix`, "what this does, and why";
`flake/modules/host-config/cube-configuration.nix` header.

## Dead ends from the port that still teach something

All of these produced no error, or an error that named the wrong thing:

- **Two `config`s in one file.** Adding an argument list to reach the NixOS
  `config` silently changed what every existing `config` in the file meant.
  This was retired on 2026-10-16, since module files can no longer take the
  flake-parts `config`.
- **starship beat powerlevel10k for a whole session.** Its init ran last in
  the generated `.zshrc`, so the 1,660-line p10k config never did anything.
  Read the generated dotfile, not the module.
- **`home.file.<n>.text` concatenates.** Two modules writing `.blerc`
  produced one file in which every import ran twice.
- **A plain NixOS module left unwrapped** dies with an `infinite recursion`
  error that blames `modulesPath`.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Dead ends, with the symptom that identified them".

## Decision: what the repo refuses to record

**Choice.** Switch state, counts of files or hosts, live versions, and
config values copied from a file the doc already links are not written
down. Docs point at the file or the command instead. Commit `4a95690`
removed such facts across the docs, and `check_wiki.py docrefs` catches the
bare count-of-files shape.

**Why.** These facts go stale without anyone noticing, and a stale fact
looks exactly like a current one. Whether a host runs what the tree
evaluates to is a live question, answered on the host with `just baseline`
or `just diff-deployed`.

Source: `AGENTS.md`, State; commit `4a95690`;
`.agents/skills/fact-hygiene/SKILL.md`.

## Decision: calibrated severity

This is a homelab config, not production. The port notes quote the
correction that set the tone: a four-day window in which the flake did not
evaluate had been over-dramatised, and "the repo has gone six months
between commits". `AGENTS.md`'s "Calibrate severity" rule comes from there.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults"; `AGENTS.md`, Working in this repo.

## Not decided: den and flake-aspects

These were commented out as inputs before the port session began. They
were never evaluated, tried, or rejected. Don't read the current design as
a verdict on them.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md).
