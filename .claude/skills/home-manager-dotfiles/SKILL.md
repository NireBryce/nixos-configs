---
name: home-manager-dotfiles
description: Traps in editing Home Manager shell/dotfile modules in this repo (zsh, bash, starship, prompt config, anything under home.file or shell initContent) or in reading a generated dotfile back to check it. Use before editing shell rc content, home.file, home.sessionPath, or when a generated dotfile looks wrong or empty.
---

# Editing Home Manager shell/dotfile modules

Home Manager is NixOS-integrated in this repo (`home-manager.users.elly` set
from the NixOS side, no separate home switch — see `CLAUDE.md`). All of the
following have actually happened here.

## `home.file.<n>.text` concatenates; it does not override

The type is `types.lines`, so two modules declaring the same file both
contribute. `.blerc` was declared by `bash.nix` and `blesh.nix` with
identical content, which would have run every `ble-import` twice. Give each
generated file one owning module. `home.sessionPath` is `listOf str` and
behaves the same way — `shell-env.nix` and `elly-session.nix` doubled every
PATH entry between them.

## Reading a generated dotfile is full of false negatives

Most shell bugs are invisible in the `.nix` and obvious in the output, but:

- **The attribute name is inconsistent.** `".zshrc"` and `"./.zshrc"` and
  full `/home/elly/...` paths all occur in this repo. A wrong name returns
  **empty rather than erroring**, which reads exactly like a real negative.
  Run `just dotfiles` first to get the actual attribute names.
- **Some entries have no `.text` at all** and are built from `.source`.
  `.bashrc` is one. Read the owning option instead — `programs.bash.initExtra`.

Both of these were hit during the original port, minutes apart, by someone
who had already written them down.

## Order in generated shell rc files is load-bearing

Home Manager emits `initContent` `mkBefore`, then `mkOrder 550`, then
`programs.zsh.plugins`, then unordered `initContent`. Anything that must run
after a plugin cannot sit at 550. Later definitions win, which is how a
hand-written `starship init bash` and a 1,659-line p10k config both turned
out to be dead weight — silently overridden, not erroring.

## Useful commands

```sh
just dotfiles        # every generated dotfile's attribute name
just dotfile ./.zshrc
```
