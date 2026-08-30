# `elly` — `nireUser/elly/`

The one category under `nireUser/` — the "for the user" area, as opposed to
`nire/` (shared system) or `nirePackages/` (packages). Don't confuse this
category with `nireUser/elly-home-manager.nix`, the entry point one level up
that assembles the *whole* `ellyHomeManager` bundle out of this category
plus several others — see [../architecture.md](../architecture.md).

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
  *because* `nire-cube` doesn't import [impermanence](impermanence.md).
  `elly-user.nix`'s `hashedPasswordFile` is unconditional, and nothing else
  in this repo tells a non-impermanence host how to actually populate that
  file — `WARN-impermanence.nix` documents the whole `/persist` dance for
  hosts that wipe `/root`, but a host with a plain persistent root has no
  equivalent pointer. Gated on
  `boot.initrd.systemd.services ? restore-root` existing (the unit only
  `WARN-impermanence.nix` creates) rather than on
  `environment.persistence`, because that option is declared for *every*
  host regardless, via `nire/system/impermanence/declare-persistence-option.nix`
  (see [system](system.md)) — so it wouldn't distinguish anything. Filed
  under `nireUser/elly/` specifically so it rides the `elly` category into
  every host automatically, cube included, rather than needing to be wired
  into cube's own host config by hand.

## Imported by

All four hosts. Every NixOS and
darwin host lists `elly` in its own per-host imports for the `nixos`/`darwin`-class
content (the account, darwin fonts); the `homeManager`-class content
(`elly-git`, `hm-config`) reaches every host via the shared
`ellyHomeManager` bundle regardless.

## See also

- [impermanence](impermanence.md) — the category whose *absence* on cube is
  what `WARN-password-required.nix` exists to flag.
- [system](system.md) — `declare-persistence-option.nix`, referenced above.
- [../architecture.md](../architecture.md) — `nireUser/elly-home-manager.nix`,
  the entry point that assembles this category into the full bundle every
  host's Home Manager actually uses.
