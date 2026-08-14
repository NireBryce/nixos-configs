# Port prompt: origin/flake-parts → flake-parts-consolidation

Kickoff prompt for a fresh Claude Code session that will port ideas from the
`origin/flake-parts` branch onto `flake-parts-consolidation`.

**Prerequisite:** the other session's handoff doc must be committed and pushed
to `origin/flake-parts` first, or step 1 of the read order will find nothing.

Everything below the line is the prompt. Paste it as-is.

---

Repo: /home/elly/projects/nixos/nixos-configs, branch flake-parts-consolidation.
This is a port, not a merge. Do not merge or rebase the branches.

SAFETY FIRST — CLAUDE.md on this branch is empty, so read this carefully:
this config enables impermanence and wipes /root on boot, and secrets are
sops-nix (secrets.yaml is encrypted and committed on purpose, not a bug).
Be careful with anything touching impermanence, fileSystems, or boot options.

## Situation

A sibling branch, origin/flake-parts, diverged from this one at cec2b84 back
in March and went a different architectural direction. It is more finished in
several respects. I want to port its good ideas here.

The two are incompatible at the root:

    this branch        — nixpkgs.lib.evalModules directly, vic/den +
                         flake-aspects, den.aspects / includes /
                         dirsAsCategory.nix, durandal only

    origin/flake-parts — real flake-parts.lib.mkFlake + flakeModules.modules,
                         plain flake.modules.nixos.* deferredModules, den
                         dropped, durandal + tenacity

Read the other branch without checking it out:

    git show origin/flake-parts:<path>
    git ls-tree -r --name-only origin/flake-parts

## Read in this order, before writing anything

1. The handoff doc the other session wrote — find it with:

       git log --oneline -5 origin/flake-parts
       git show --stat origin/flake-parts

   It's PORT-NOTES.md or linux-flake/notes-and-fixes.md. It covers why den
   was dropped, dead ends, and load-bearing constraints.

2. `git show origin/flake-parts:CLAUDE.md` (338 lines, substantive)

3. `git show origin/flake-parts:linux-flake/flake.nix`
   vs this branch's linux-flake/flake.nix

4. The three files that carry the ideas worth porting:

       git show origin/flake-parts:linux-flake/modules/roles.nix
       git show origin/flake-parts:linux-flake/modules/checks.nix
       git show origin/flake-parts:linux-flake/modules/hosts/hosts.nix

5. This branch: linux-flake/modules/entrypoint.nix and
   linux-flake/modules/nireHost/aspect-durandal.nix — both carry
   "# TODO: this is wrong and will need to be modified for flake-parts"

Verify all of the above against the actual files. Don't trust this summary.

## The decision gate

Before proposing any change, tell me: based on the handoff doc, do we keep
vic/den and port ideas onto it, or abandon den and adopt real flake-parts?
Everything else depends on that. Stop and ask me — do not pick for me.

## Candidate targets, roughly in value order

- **roles.nix** — modules opt *themselves* into base/desktop/handheld
  aggregates via `flake.modules.nixos.base.imports = [ ... ]`, next to their
  own definition. Adding a module becomes a one-file change instead of also
  editing every host. This replaces the hand-maintained `moduleList` in
  aspect-durandal.nix, which already has a "# TODO: there has to be a better
  way" on exactly this problem. Highest value regardless of how the den
  question resolves.

- **checks.nix** — makes `nix flake check` force every host's toplevel
  derivation, plus a python orphan-module detector for modules nothing
  imports. This branch has no real checks. Read its comment header: both
  bugs it was written to catch were pure evaluation errors.

- **The .justfile and linux-flake/scripts/** (modules.py, diff-config.sh,
  dotfile.sh, add-pkg.sh, new-host-hardware.sh, host-fingerprint.nix,
  update-flake.sh). This branch's .justfile is comments only.

- **CLAUDE.md** — port it, but correct it for this branch's actual
  architecture. Do not copy it verbatim; much of it describes flake-parts
  internals that may not apply here.

- **Tenacity** — do NOT port from origin/flake-parts. Its config there is a
  414-byte stub (hostPlatform, stateVersion, hostName, and imports of the
  `handheld` + `tenacityHardware` aggregates); all behavior comes from the
  role aggregate, so there is no content to carry over.

  This branch has no tenacity files at all — the den restructure dropped the
  host rather than migrating it, so it's been durandal-only since. The only
  traces are .justfile comments and its enrollment in
  linux-flake/modules/nire/system/secrets/.sops.yaml + secrets.yaml, so the
  key is still valid.

  Evaluate any tenacity work against how the actual tenacity machine behaves
  now, not against either branch's files. The last real tenacity config in
  this branch's own lineage is pre-divergence at 86d9f6d:

      git show 86d9f6d:linux-flake/configs/hosts/nire-tenacity/hw-conf/hardware-configuration.nix
      git show 86d9f6d:linux-flake/configs/hosts/nire-tenacity/peripherals.nix
      git show 86d9f6d:linux-flake/configs/system-config/nire-tenacity-configuration.nix

  Treat those as reference only, and regenerate hardware config on the machine
  itself rather than trusting a year-old file. Ask me before adding the host
  back — I may not want it re-introduced during the port. Re-adding a host
  mid-port means debugging two machines' worth of evaluation errors at once,
  before the architecture decision has even landed.

## Open questions I have not decided

- Whether the `darwin` input currently in linux-flake/flake.nix stays there,
  or moves back out to a separate macos/ flake the way origin/flake-parts has
  it. Raise this once the den question is settled; don't act on it unasked.

## How to work

Plan first, ask before editing files — I want to approve changes. Note that
linux-flake/modules/nirePackages/editors/vscode/vscode.nix has uncommitted
changes in the working tree right now. Work in small commits.
