---
name: home-manager-dotfiles
description: Edits Home Manager shell and dotfile modules and reads a generated dotfile back correctly.
when_to_use: Editing zsh, bash or starship rc content, home.file or home.sessionPath, or a generated dotfile looks wrong or empty.
---

# Editing Home Manager shell/dotfile modules

## Applies to

Use this before editing Home Manager (HM) shell or dotfile modules (zsh, bash, starship, prompt config, anything under `home.file` or shell `initContent`), `home.sessionPath`, or when a generated dotfile looks wrong or empty.

HM is NixOS-integrated: `home-manager.users.elly` is set from the NixOS side and there is no separate home switch (`CLAUDE.md`). Consequences:

- HM rejects `nixpkgs.*` under `useGlobalPkgs` with an error. `allowUnfree` comes from the system side, `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as a systemd unit whose `PATH` holds only coreutils, findutils, gnugrep, gnused and systemd.

## `home.file.<n>.text` concatenates; it does not override

The option type is `types.lines`, so two modules declaring one file both contribute to it. `bash.nix` and `blesh.nix` both declared `.blerc` with identical content, so every `ble-import` ran twice. Give each generated file one owning module. `home.sessionPath` (`listOf str`) behaves the same way: `shell-env.nix` and `elly-session.nix` doubled every PATH entry.

## Reading a generated dotfile: false negatives

- **Attribute names are inconsistent.** `".zshrc"`, `"./.zshrc"` and full `/home/elly/...` paths all occur. A wrong name returns an empty result, not an error, which looks the same as a real negative. Run `just dotfiles` first to get the actual names.
- **Some entries have no `.text`**, only `.source` (`.bashrc`). Read the owning option instead (`programs.bash.initExtra`).

## rc ordering is load-bearing

HM emits `initContent` in this order: `mkBefore`, then `mkOrder 550`, then `programs.zsh.plugins`, then unordered `initContent`. Anything that must run after a plugin cannot sit at 550. Later definitions win silently: a hand-written `starship init bash` and a 1,659-line p10k config were both overridden without an error.

## Commands

```sh
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
```
