# Kickoff prompt: the instance running on nire-tenacity

Companion to `../HANDOFF-tenacity.md`, which carries the detail. Written by
Darryl (worked `flake-parts-consolidation` from the darwin laptop), following
Alice on the sibling `flake-parts` branch and Bob who wrote `old-historical-port-prompt.md`
in this directory.


Everything below the line is the prompt. Paste it as-is, after substituting the
repo path.

---

You're running on nire-tenacity, a GPD Win Mini handheld running NixOS. Unlike the previous claude code instances, since the machine runs nixos you have the ability to build not just eval. all builds should be dry-run, if other forms are necessary explicitly ask.

The
repo is at `/home/elly/projects/nix/flake-parts-condolidation-prime`, branch `flake-parts-consolidation`. Fetch first — the tip
should be 61d1d30 or later. If it isn't, stop and tell me; you'd be working
against a tree that predates this host existing in the config at all.

SAFETY, before you touch anything:
- This config enables impermanence. It deletes the /root btrfs subvolume in
  initrd on every boot. Be careful with anything under
  flake/modules/nire/boot/ or the fileSystems/boot options.
- Secrets are sops-nix. secrets.yaml is encrypted and committed on purpose;
  that is not a mistake to fix.

Read HANDOFF-tenacity.md at the repo root first, then CLAUDE.md.

The handoff was written by the previous instance — Darryl — working from my
darwin laptop, and it exists because of one fact: nothing on this branch has been
built or switched. origin/main merged flake-parts a while back and is what these
machines actually run, so the architecture is proven; what is untested is the
~172 commits this branch stacks on top of it. Every "verified" claim in the docs
and commit messages from that work means "it evaluates", never "it runs". You are
the first instance on the actual hardware, and that is the whole point of you.

Work the handoff's checklist in the order it gives. Stop and check with me
before any of:
- `just switch`
- rebooting
- the hardware config not matching the disk
- root-blank being absent

Expect `just build` to surface things evaluation could not. jovian.nix and the
handheld stack behind it have never been built by anything.

Tell me what you find before you decide what to do about it.

---

## Why it is shaped this way

**Safety before orientation.** Impermanence and sops come first, before the
instance has any reason to start poking at things. Both are cases where the
natural helpful instinct is actively wrong — "fixing" a committed encrypted
file, or treating `/root` as ordinary state.

**The tip check is a stop condition, not a suggestion.** An instance working
against the pre-push tree will not find tenacity in the config and will
plausibly set about adding it again.

**"Every verified claim means it evaluates."** The single most useful thing to
hand over. There are a lot of confident verification claims in those commit
messages and every one of them has that ceiling. Scoped to the branch rather than
the repo, which is a correction Elly had to make — origin/main is deployed and is
already flake-parts, so "none of this has ever worked" would be false and would
overstate the risk.

**Explicit stop points.** The four listed are where an instance can do something
that cannot be undone from a chat window.

Deliberately left out: the working conventions (`git add` before `nix eval`,
never run `nix fmt`, module filenames are attribute names) are in `CLAUDE.md`
and the last section of the handoff. Repeating them here would dilute the safety
items, which are the part that has to land in the first thirty seconds.

Also left out: a name. Alice, Bob, Darryl leaves C conspicuously open.  That's because 'Claude' starts with C, and it would be confusing to have multiple C names.
