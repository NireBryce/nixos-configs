---
name: home-manager-dotfiles
description: How to edit Home Manager shell/dotfile modules in this repo, and read a generated dotfile back correctly.
---

# Editing Home Manager shell/dotfile modules

## Applies to

Home Manager shell/dotfile modules (zsh, bash, starship, prompt config, anything under `home.file` or shell `initContent`) and reading a generated dotfile back. Use before editing shell rc content, `home.file`, `home.sessionPath`, or when a generated dotfile looks wrong or empty.

HM is NixOS-integrated (`home-manager.users.elly` from the NixOS side, no separate home switch; `CLAUDE.md`). Integration facts:

- HM **rejects** `nixpkgs.*` under `useGlobalPkgs` (error, not ignored); `allowUnfree` comes from the system side, `basic-nix-settings.nix`.
- `home.profileDirectory` is `/etc/profiles/per-user/elly`, not `~/.nix-profile`.
- Activation runs as a systemd unit; its `PATH` is only coreutils/findutils/gnugrep/gnused/systemd.

## `home.file.<n>.text` concatenates; it does not override

Type is `types.lines`: two modules declaring one file both contribute. `.blerc` was declared by `bash.nix` and `blesh.nix` with identical content (every `ble-import` would run twice). One owning module per generated file. `home.sessionPath` (`listOf str`) behaves the same: `shell-env.nix` and `elly-session.nix` doubled every PATH entry.

## Reading a generated dotfile: false negatives

- **Attribute names are inconsistent**: `".zshrc"`, `"./.zshrc"`, and full `/home/elly/...` all occur. A wrong name returns **empty, not an error**, indistinguishable from a real negative. Run `just dotfiles` first for actual names.
- **Some entries have no `.text`**, only `.source` (`.bashrc`). Read the owning option instead (`programs.bash.initExtra`).

Both hit minutes apart during the original port, by someone who had already written them down.

## rc ordering is load-bearing

HM emits `initContent` `mkBefore`, then `mkOrder 550`, then `programs.zsh.plugins`, then unordered `initContent`. Anything that must run after a plugin can't sit at 550. Later definitions win: a hand-written `starship init bash` and a 1,659-line p10k config were both silently overridden, not erroring.

## Commands

```sh
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
```
