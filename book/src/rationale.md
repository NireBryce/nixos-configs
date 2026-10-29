# Why it is built this way

Most odd-looking parts of this tree were chosen on purpose. This chapter lists
those decisions and the dead ends that led to them, each dead end named by the
symptom that identified it. Read it before you "tidy" something that looks
odd: the repo treats re-deciding a choice without saying so as worse than
either answer. Terms such as *category*, *aggregate* and *deferred module*
are in the [glossary](glossary.md).

## Older commits may be missing from your clone

A shallow clone (`git rev-parse --is-shallow-repository` prints `true`)
has a graft commit at its oldest point that holds the whole earlier tree.
Commits the docs cite from before the graft are not objects you can read,
including the tip of the deleted `flake-parts` branch: `git cat-file -t
<hash>` answers "not a valid object".

For anything older than your clone's history, the sections below rely on the
dated working notes in `flake/doc/` and `wiki/` rather than `git log`. To
check a claim against a full history, use the `git-archaeology` skill
(`.agents/skills/git-archaeology/SKILL.md`) in a full clone.

## Decision: flake-parts, for one option

The flake is built with flake-parts, a library for writing a flake as
module-system modules. The reason is a single option,
`flake.modules.<class>.<name>`, which `flakeModules.modules` declares as a
`deferredModule`. A deferred module is stored unevaluated, to be imported
later by a NixOS, Home Manager or darwin configuration.

With that option, one file can hold a NixOS module and a Home Manager module
for the same feature as sibling attributes. Without it, the two would be
separate files tied together only by a shared filename. The worked example
is the old `nixd.nix`, which installed `nixd` both system-wide and in Home
Manager from one file.

The rationale note lists which flake-parts features are used and which are
not. Unused: `moduleWithSystem`, `debug`, overlay or `legacyPackages`
composition, and any bundled flake module other than `modules` and
`touchup`. `perSystem` is used for checks, the dev shell and the nix-topology
output, and `withSystem` is used only in `hosts.nix`.

## Decision: hosts build their own `pkgs`

`hosts.nix` uses `withSystem` only to get `self'` and `inputs'` into
`specialArgs`. It does **not** pass perSystem's `pkgs` to the hosts.

perSystem's `pkgs` is built from the fleet's shared `nixpkgs.config`
(`flake/modules/_lib/nixpkgs.nix`), so checks and the dev shell see the same
unfree policy as the hosts. The hosts build their own instance from that
config, at the cost of a second nixpkgs instantiation. Reusing perSystem's
would mean `nixpkgs.pkgs`, under which NixOS ignores `nixpkgs.config`, and
`hostPlatform` and overlays would move with it.

## Decision: membership by directory

A module belongs to the category of the folder it sits in. The
`dirsAsCategory.md` note says this was repaired rather than replaced during
the flake-parts port.

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

The opt-in pattern was tested before the sibling branch adopted it, with a
throwaway `mkFlake` whose two modules each set the same aggregate's `imports`;
both definitions survived. Before categories were repaired, the self-reference
they depend on was modelled and evaluated first ([lesson
12](../../wiki/agent-lessons-learned/12-verify-mechanism-before-refactor.md)).

`flake/doc/dirsAsCategory.md` keeps a "How to convert" section as a
documented way back. The user has chosen this pattern three times: when a
choice is close, keep a documented escape hatch and stop re-arguing the
choice ([lesson
13](../../wiki/agent-lessons-learned/13-reversibility-for-decision.md)).

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
and the shims. It takes the name from the file and works out categories from
the shape of the tree, so no file states either. The move was checked by
comparing every host's toplevel `drvPath` (the store path of the system
derivation), and the fingerprints, before and after.

## Dead end: same-named modules merging without an error

Importing the `boot` category once applied durandal's bootloader, because
durandal's `boot.nix` and the `general-config/boot/` category shared the
name `boot` and merged ([lesson
34](../../wiki/agent-lessons-learned/34-collision-where-both-halves-work.md)).
A second near-miss had no visible symptom at all. A `virtualization/` category
holding a `virtualization.nix` would have merged two halves that were both
libvirt config. Everything would still have worked until someone imported the
category expecting only the category.

A merge of the two halves shows only when they disagree. Give the file the
specific name (`libvirt.nix`, `podman.nix`) and leave the general name to the
category. Evaluation now enforces this naming rule.

## Decision: Home Manager integrated into NixOS

Home Manager is wired in from the system side, chosen over standalone Home
Manager and over keeping both. One switch covers system and home, there is
one nixpkgs instantiation, and the home config cannot drift out of sync with
its system. The costs (home modules may not set `nixpkgs.*`, a different
profile directory, activation as a systemd unit with a minimal `PATH`, no
standalone home switch) are listed in [Wiring a user and Home
Manager](users-and-home-manager.md).
`flake/doc/trailhead-home-manager-standalone.md` is the documented way back.

## Decision: package parity across hosts

Hosts are not split by role. The handheld gets the full desktop GUI set
(`vscode`, `gimp`, `libre-office`, `zoom`, …). A split was offered and
declined, and the structure was left able to split later.

As a consequence, `packages-config/` has one file per package (the "full
per-file dendritic conversion"). The boilerplate was accepted. Categories
have superseded the old role names `base` / `desktop` / `handheld`.

## Decision: derived platform support, never derived Homebrew overlap

One module, `drop-unsupported-packages.nix`, filters `home.packages` by
`meta.platforms` on darwin only, replacing hand-written `isDarwin` guards
that each restated a fact nixpkgs already knows. The filter does not catch
`meta.broken` or Homebrew overlap, by design. [Adding a
package](adding-a-package.md) walks through the guards and the overlap check.

## Decision: `nix fmt` is not wired up

The modules align their `=` signs in columns on purpose. A formatter would
flatten them, so `treefmt` is absent and the flake's `formatter` output is
turned off with `touchup`.

A CI failure forced the `touchup` line. CI's first real run failed
`nix flake check` with "flake-parts could not determine statically that no
formatter is defined". The error reproduced on a fresh clone too. It had
been missed locally partly because the check was piped through `tail`, and a
pipeline reports the exit status of its last command ([lesson
20](../../wiki/agent-lessons-learned/20-pipeline-exit-status.md)).

## Decision: impermanence on some hosts

Hosts that include the `impermanence` category wipe `/root` on every boot,
so that any state that matters has to be declared in the repo. A forgotten
path then fails the next day. Without the wipe, it would surface years later
with no warning. A host installed by hand with a plain root opts out;
`cube-configuration.nix` is the worked example. The mechanism is in [Wiring a
host](wiring-a-host.md#read-this-first-the-root-wipe).

## Dead ends from the port that still teach something

Each of these produced no error, or an error that named the wrong thing:

- Two `config`s in one file. Adding an argument list to reach the NixOS
  `config` changed what every existing `config` in the file meant, with no
  error. Module files can no longer take the flake-parts `config`, so the
  trap is retired.
- starship beat powerlevel10k for a whole session. starship's init ran last
  in the generated `.zshrc`, so the very long p10k config never did
  anything. Read the generated dotfile, not the module.
- `home.file.<n>.text` concatenates. Two modules writing `.blerc` produced
  one file in which every import ran twice.
- A plain NixOS module left unwrapped died with an `infinite recursion`
  error that blamed `modulesPath`. The library now refuses it with advice.

## Decision: what the repo refuses to record

The repo does not write down switch state, counts of files or hosts, live
versions, or config values copied from a file the doc already links. Docs
point at the file or the command instead. `check_wiki.py docrefs` catches the
bare count-of-files shape.

Such facts go stale without anyone noticing, and a stale fact looks exactly
like a current one. Whether a host runs what the tree evaluates to is a live
question, answered on the host with `just baseline` or `just diff-deployed`.

## Decision: calibrated severity

The repo is a homelab config. The port notes quote the correction that set
the tone: a short window in which the flake did not evaluate had been
over-dramatised, and the repo can go months between commits. `AGENTS.md`'s
"Calibrate severity" rule comes from that correction.

## Not decided: den and flake-aspects

den and flake-aspects were commented out as inputs before the port session
began. They were never evaluated, tried, or rejected. The current design is
not a verdict on them.

## Sources

- `flake/doc/flake-parts-rationale.md`, `flake/doc/dirsAsCategory.md`,
  `flake/doc/trailhead-home-manager-standalone.md`
- `flake/modules/host-config/hosts.nix`,
  `flake/modules/host-config/cube-configuration.nix`,
  `flake/modules/host-config/tenacity-configuration.nix`
- `flake/modules/general-config/system/home-manager/drop-unsupported-packages.nix`
- `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
- `flake/flake.nix` (`touchup`), `AGENTS.md`
- `.agents/skills/new-flake-module/SKILL.md`,
  `.agents/skills/fact-hygiene/SKILL.md`,
  `.agents/skills/git-archaeology/SKILL.md`
- [flake-parts.md](../../wiki/config-structure/flake-parts.md)
- [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md)
- [module-files.md](../../wiki/config-structure/module-files.md)
- [module-style-guide-for-agents.md](../../wiki/config-structure/module-style-guide-for-agents.md)
