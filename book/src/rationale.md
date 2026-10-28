# Why it is built this way

Most odd-looking parts of this tree were chosen on purpose. Below are those
decisions and the dead ends that led to them, each dead end named by the
symptom that identified it. Read them before you "tidy" something that looks
odd: the repo treats re-deciding a choice without saying so as worse than
either answer. Terms such as *category*, *aggregate* and *deferred module*
are defined in the [glossary](glossary.md).

## Older commits may be missing from your clone

A shallow clone (`git rev-parse --is-shallow-repository` prints `true`)
has a graft commit at its oldest point that holds the whole earlier tree.
Commits the docs cite from before the graft are not objects you can read,
including the tip of the deleted `flake-parts` branch: `git cat-file -t
<hash>` answers "not a valid object".

For anything older than your clone's history, the sections below rely on the
dated working notes in `flake/doc/` and `wiki/` rather than `git log`. To
check one of those claims against a full history, use the `git-archaeology`
skill (`.agents/skills/git-archaeology/SKILL.md`) in a full clone.

## Decision: flake-parts, for one option

The flake is built with flake-parts, a library for writing a flake as
module-system modules. The stated reason is a single option,
`flake.modules.<class>.<name>`, which `flakeModules.modules` declares as a
`deferredModule`. A deferred module is stored unevaluated, to be imported
later by a NixOS, Home Manager or darwin configuration.

With that option, one file can hold a NixOS module and a Home Manager module
for the same feature as sibling attributes. Without it, the two would be
separate files tied together only by a shared filename. The worked example
is the old `nixd.nix`, which installed `nixd` both system-wide and in Home
Manager from one file.

The rationale note lists, from grep, which flake-parts features are used and
which are not. Unused: `moduleWithSystem`, `debug`, overlay or
`legacyPackages` composition, and any bundled flake module other than
`modules` and `touchup`. `perSystem` is used for checks, the dev shell and the
nix-topology output, and `withSystem` is used only in `hosts.nix`.

Source: `flake/doc/flake-parts-rationale.md`;
[flake-parts.md](../../wiki/config-structure/flake-parts.md).

## Decision: hosts build their own `pkgs`

`hosts.nix` uses `withSystem` only to get `self'` and `inputs'` into
`specialArgs`. It does **not** pass perSystem's `pkgs` to the hosts.

perSystem is flake-parts' per-system scope. Its default `pkgs` is
`legacyPackages.<system>` with no `nixpkgs.config` applied. Using that `pkgs`
would drop `allowUnfree` without an error, and these hosts install unfree
packages.
The accepted cost is a second nixpkgs instantiation. The design is under
review in [issue 559](https://github.com/NireBryce/nixos-configs/issues/559).

Source: `flake/modules/host-config/hosts.nix` (comments above `mkHost`);
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"`withSystem`".

## Decision: membership by directory

A module belongs to the category of the folder it sits in; a category is a
folder whose modules a host can take by one name. The `dirsAsCategory.md`
note dates the choice to commit `0c0b5f0` and says it was repaired rather
than replaced during the flake-parts port.

The sibling `flake-parts` branch used per-module opt-in, where each module
declares which aggregates it joins. (An aggregate is a module that exists to
import other modules by name.) Per-module opt-in has advantages: directory
and membership come apart, a module can join several roles, and the result
is greppable. The note lists its costs:

- An opt-in line per module.
- No file that shows a roster.
- A new failure that reports nothing. Leave out the opt-in line and the
  module is valid, evaluates cleanly, and installs nothing. No evaluation can
  ever report this mistake.
- Same-named modules merge, with no error.

Categories cannot fail that way, because membership is automatic.

The opt-in pattern was tested before the sibling branch adopted it. Someone
built a throwaway `mkFlake` with two modules that each set the same
aggregate's `imports`, and confirmed that both definitions survived. Later,
before categories were repaired rather than replaced, the self-reference they
depend on was modelled and evaluated first (§12 in
[agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)).

`flake/doc/dirsAsCategory.md` keeps a "How to convert" section as a
documented way back. Nire has chosen this pattern three times: when a
choice is close, keep a documented escape hatch and stop re-arguing the
choice (§13).

Source: `flake/doc/dirsAsCategory.md`, "What the alternative is";
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Dead ends"; `wiki/agent-lessons-learned/13-reversibility-for-decision.md`.

## Dead end: hand-written module names and category shims

Until the change to dirs-as-categories, every module computed its own name
from `__curPos.file`. Every category folder held an identical copy of a
shim, `dirsAsCategory.nix`, which called a shared collector in `_lib/`.

That arrangement produced three symptoms:

- A module whose hand-written name differed from its filename dropped out
  of every category, and nothing reported an error.
- Shims that should have been byte-identical drifted. Hashing found copies
  that differed by a comment word.
- A renamed shim once made nested categories collect a phantom module
  called `dirsAsCategory`. The class filter hid the phantom.

The `dirs-as-categories` flake input replaced both the hand-written names
and the shims. The input takes the name from the file and works out
categories from the shape of the tree, so no file states either. Same-named
modules now fail evaluation. The move was checked by comparing every host's
toplevel `drvPath` (the store path of the system derivation), and the
fingerprints, before and after.

Source: [module-files.md](../../wiki/config-structure/module-files.md),
"Why the name comes from the filename", "Why categories need no shim", "How
the move was checked"; `flake/doc/dirsAsCategory.md`, "Things that are
load-bearing" and its History banner.

## Dead end: same-named modules merging without an error

Importing the `boot` category once applied durandal's bootloader, because
durandal's `boot.nix` and the `general-config/boot/` category shared the
name `boot` and merged. A second near-miss had no visible symptom at all. A
`virtualization/` category holding a `virtualization.nix` would have merged
two halves that were both libvirt config. Everything would still have worked
until someone imported the category expecting only the category.

The lesson: a merge is visible only when the two halves disagree. Give the
file the specific name (`libvirt.nix`, `podman.nix`) and leave the general
name to the category. Evaluation now enforces this naming rule.

Source: `wiki/agent-lessons-learned/34-collision-where-both-halves-work.md`;
`.agents/skills/new-flake-module/SKILL.md`, "Names share one namespace".

## Decision: Home Manager integrated into NixOS

Home Manager, which manages a user's packages and dotfiles as modules, is
wired in from the system side. It was chosen over standalone Home Manager,
and over keeping both. The NixOS-side bridge sets `useGlobalPkgs` (Home
Manager uses the system's nixpkgs) and `useUserPackages` (packages go into
the system's per-user profile).

The integration bought:

- one switch for both system and home;
- one nixpkgs instantiation;
- a home config that cannot drift out of sync with its system.

It cost:

- Home modules may not set `nixpkgs.*`; doing so is an error.
- The home profile directory moves to `/etc/profiles/per-user/<name>`.
- Activation runs as a systemd unit with a minimal `PATH`.
- The home config can't be switched on its own.

`flake/doc/trailhead-home-manager-standalone.md` is the documented way back.
For more detail, see [Wiring a user and Home Manager](users-and-home-manager.md).

Source: `flake/doc/trailhead-home-manager-standalone.md`, "What integrated
actually bought and cost";
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults".

## Decision: package parity across hosts

Hosts are not split by role. The handheld gets the full desktop GUI set
(`vscode`, `gimp`, `libre-office`, `zoom`, …). A split was offered and
declined, and the structure was left able to split later.

As a consequence, `packages-config/` has one file per package (the "full
per-file dendritic conversion"). The boilerplate was accepted. Categories
have superseded the old role names `base` / `desktop` / `handheld`.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults"; comment above the package categories in
`flake/modules/host-config/tenacity-configuration.nix`.

## Decision: derived platform support, never derived Homebrew overlap

One module, `drop-unsupported-packages.nix`, filters `home.packages` by
`meta.platforms`, on darwin only, and warns by name about each package it
drops. It replaced hand-written `isDarwin` guards that were all correct but
each restated a fact nixpkgs already knows. On Linux the filter does nothing:
a package that can't build on Linux is a mistake, and it should stay a loud
error.

The filter does not catch `meta.broken`, by design. It does not detect
Homebrew overlap either; `just available --duplicates` is the tool for that.
[Adding a package](adding-a-package.md) walks through both.

Source: header of
`flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`;
`.agents/skills/package-platform-support/SKILL.md`.

## Decision: `nix fmt` is not wired up

The modules align their `=` signs in columns on purpose. A formatter would
flatten them, so `treefmt` is absent and the flake's `formatter` output is
turned off with `touchup`.

A CI failure forced the `touchup` line. CI's first real run failed
`nix flake check` with "flake-parts could not determine statically that no
formatter is defined". The error reproduced on a fresh clone too. It had
been missed locally partly because the check was piped through `tail`. A
pipeline reports the exit status of its last command, here `tail` (§20).

Source: comment on `touchup` in `flake/flake.nix`;
[module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md),
"Formatting".

## Decision: impermanence on some hosts

Hosts that include the `impermanence` category wipe `/root` on every boot,
so that any state that matters has to be declared in the repo. A forgotten
path then fails loudly the next day. Without the wipe, it would surface
years later with no warning. A
host installed by hand with a plain root opts out. Its entry point says so
and explains how the checks opt out with it. The cube host's entry point,
`cube-configuration.nix`, is the worked example.

Source: `WARN-impermanence.nix`, "what this does, and why";
`flake/modules/host-config/cube-configuration.nix` header.

## Dead ends from the port that still teach something

Each of these produced no error, or an error that named the wrong thing:

- Two `config`s in one file. Adding an argument list to reach the NixOS
  `config` changed what every existing `config` in the file meant, with no
  error.
  The trap is retired, since module files can no longer take the
  flake-parts `config`.
- starship beat powerlevel10k for a whole session. starship's init ran last
  in the generated `.zshrc`, so the very long p10k config never did
  anything. Read the generated dotfile, not the module.
- `home.file.<n>.text` concatenates. Two modules writing `.blerc` produced
  one file in which every import ran twice.
- A plain NixOS module left unwrapped died with an `infinite recursion`
  error that blamed `modulesPath`. The library now refuses it with advice.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Dead ends, with the symptom that identified them" and "import-tree";
[module-files.md](../../wiki/config-structure/module-files.md), "Three kinds of
module, and what to call each" (the current refusal).

## Decision: what the repo refuses to record

The repo does not write down switch state, counts of files or hosts, live
versions, or config values copied from a file the doc already links. Docs
point at the file or the command instead. Commit `4a95690` removed such
facts across the docs, and `check_wiki.py docrefs` catches the bare
count-of-files shape.

Such facts go stale without anyone noticing, and a stale fact looks exactly
like a current one. Whether a host runs what the tree evaluates to is a live
question, answered on the host with `just baseline` or `just diff-deployed`.

Source: `AGENTS.md`, State; commit `4a95690`;
`.agents/skills/fact-hygiene/SKILL.md`.

## Decision: calibrated severity

The repo is a homelab config. The port notes quote the correction that set
the tone: a short window in which the flake did not evaluate had been
over-dramatised, and the repo can go months between commits. `AGENTS.md`'s "Calibrate severity" rule comes from that correction.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"Decisions, not defaults"; `AGENTS.md`, Working in this repo.

## Not decided: den and flake-aspects

den and flake-aspects were commented out as inputs before the port session
began. They were never evaluated, tried, or rejected. Don't read the current
design as a verdict on them.

Source: [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md).
