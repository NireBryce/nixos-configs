# 36. Evaluating the Nix expression and building the artifact it describes are different tests, and only one of them was run

_Last modified: 2026-09-09_

§36 of [lessons-learned.md](../lessons-learned.md#36-evaluating-the-nix-expression-and-building-the-artifact-it-describes-are-different-tests-and-only-one-of-them-was-run) — that page keeps the one-line version of every lesson; this is §36's full account.

Two real bugs surfaced building `nire-llm-sandbox` (a libvirt VM guest on
cube), and both share a shape worth naming on its own,
past what §25 ("running it is a rung of its own") already covered:

1. Using `image.modules.qemu` (nixpkgs' image-*variant* system) instead of
   importing `virtualisation/disk-image.nix` directly. This one WAS caught
   by evaluation — `nix eval` on `system.build.toplevel` failed outright,
   with a real assertion naming the missing `fileSystems`/`grub.devices`.
   Forcing every touched host's toplevel (this repo's own standing rule,
   `checks.nix`'s whole reason for existing) is what caught it, immediately,
   before anything was built.
2. Using `config.image.filePath` as if it were already an absolute path,
   when it's documented as relative to the image derivation's own `$out`.
   This one was NOT caught by evaluation — `nix eval` on the consuming
   systemd unit's `ExecStart` returned a perfectly well-typed store path to
   a generated script. The script's own *content* was wrong (a bare filename
   in an `[ -e ... ]` check, certain to fail under systemd's cwd), and
   nothing about evaluating the expression that produced it revealed that —
   only building the script and reading it back did.

**Bug #1 is the "evaluates ≠ works" lesson this file already has (§25),
found the normal way. Bug #2 is one level past it: a value can be
well-typed, evaluate cleanly, and still be semantically wrong — and no
amount of `nix eval` on the *consumer* finds that, because the consumer
faithfully substituted a bad string into a syntactically fine derivation.**
The only thing that caught it was `nix build`-ing the specific derivation
whose *string content* mattered and reading the file back — the same
`Read`-the-artifact discipline this repo already applies to generated
dotfiles (`home-manager-dotfiles` skill) and rendered firewall scripts
(wiki `system.md`'s Tailscale section), just not yet named as a general
rule. Worth generalizing: **when a value is a path, a filename, or anything
else whose correctness depends on more than its type, build the thing that
consumes it and read the result — don't stop at the expression type-checking.**
