# `elly` — `users/elly/`

_Last modified: 2026-09-14_

The one category under `users/` — the "for the user" area, as opposed to
`config-system/` (shared system) or `packages/` (packages). Don't confuse this
category with `users/elly-home-manager.nix`, the entry point one level up
that assembles the *whole* `ellyHomeManager` bundle out of this category
plus several others — see [../architecture.md](../architecture.md).

## Contents

- [What's in it](#whats-in-it)
- [Imported by](#imported-by)
- [`elly` as the experimental user](#elly-as-the-experimental-user)
- [See also](#see-also)

## What's in it

- **`elly-git/elly-git.nix`** — `homeManager`-only: `programs.git`, a
  `.gitconfig` written from `home.file`, and aliases (`pushall`, `graph`,
  `add-nowhitespace`).
- **`hm-config/hm-config.nix`** — `homeManager`-only, and tiny:
  `home.stateVersion`, `home.username`, `home.homeDirectory` — all
  `lib.mkDefault`, with a comment flagging that darwin's home directory
  differs (though the actual value isn't branched here; it's a default
  meant to be overridden per-platform if one ever needs to).
- **`user-settings/elly-user.nix`** — both `nixos`- and `darwin`-class: the
  account itself on the NixOS side (`users.mutableUsers = false`,
  `isNormalUser = true`, `extraGroups = [ "wheel" "audio" "podman" ]`) and,
  on darwin, the nerd-font packages Home Manager's terminal config expects
  to already be on the system. Carries its own open TODO ("these modules
  should be stored outside of the users folder, so it's clearer when it's
  imported").
- **`user-settings/WARN-password-required.nix`** — the module that exists
  *because* a non-impermanence host doesn't import
  [impermanence](impermanence.md). `elly-user.nix`'s `hashedPasswordFile` is
  unconditional, and nothing else in this repo tells such a host how to
  actually populate that file — `WARN-impermanence.nix` documents the whole
  `/persist` dance for hosts that wipe `/root`, but a host with a plain
  persistent root has no equivalent pointer. Gated on
  `boot.initrd.systemd.services ? restore-root` existing (the unit only
  `WARN-impermanence.nix` creates) rather than on
  `environment.persistence`, because that option is declared for *every*
  host regardless, via `config-system/system/impermanence/declare-persistence-option.nix`
  (see [system](system.md)) — so it wouldn't distinguish anything. `nire-cube`
  is additionally excluded by hostname: the module used to fire on cube too,
  but its password hash was created by hand on the real machine before cube
  was ever switched, and a plain persistent root never wipes it back out, so
  the reminder had nothing left to remind about there (fixed 2026-09-01).
  Filed under `users/elly/` specifically so it rides the `elly` category
  into every host automatically — including any *future* non-impermanence
  host, which would still get the warning — rather than needing to be wired
  in by hand.

## Imported by

All four hosts. Every NixOS and
darwin host lists `elly` in its own per-host imports for the `nixos`/`darwin`-class
content (the account, darwin fonts); the `homeManager`-class content
(`elly-git`, `hm-config`) reaches every host via the shared
`ellyHomeManager` bundle regardless.

## `elly` as the experimental user

`elly` is deliberately the *experimental* user — everything new lands here
first, not on a separate stable account. The long-term plan (not yet
started) is a two-step split: offload what's really user-package material
onto `nire`, then, once the config has stabilized, split anything that
doesn't need direct human invocation into its own dedicated user account —
a confused-deputy mitigation, so a compromised or misbehaving program
running as one of those users doesn't inherit the whole of `elly`'s
authority. `nire.primaryUser` from the deleted `flake-parts` branch
(see [../flake-parts-port-notes.md](../flake-parts-port-notes.md)) is
adjacent but not the same thing — that was about which user's config gets
built, not about isolating non-interactive programs from `elly`.

Noted here rather than deferred indefinitely because rebuilding and
switching a host is now cheap enough for an agent to do routinely — the
migration was previously gated on how much manual effort a user split
would cost to land and verify, and an LLM driving `just switch` on real
hardware removes most of that cost. See top-level [../../README.md](../../README.md)'s
Users section for the same plan stated for a human reader.

## See also

- [impermanence](impermanence.md) — the category whose *absence* is what
  `WARN-password-required.nix` exists to flag (cube itself is now excluded
  by hostname, since its password was already solved by hand).
- [system](system.md) — `declare-persistence-option.nix`, referenced above.
- [../architecture.md](../architecture.md) — `users/elly-home-manager.nix`,
  the entry point that assembles this category into the full bundle every
  host's Home Manager actually uses.
