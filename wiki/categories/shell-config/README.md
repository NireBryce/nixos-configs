# `shell-config` — `nire/shell-config/`

## Contents

- [What's in it](#whats-in-it)
- [The `home.file`/`home.sessionPath` concatenation trap, live in this category](#the-homefilehomesessionpath-concatenation-trap-live-in-this-category)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

- **`bash/bash.nix`** — `nixos`-class: `environment.pathsToLink` for bash
  completion, `environment.shells`. `homeManager`-class: bash itself as a
  line editor for zsh-like bindings.
- **`bash/blesh.nix`** — the `.blerc` config, `homeManager`-only. Owns the
  file outright: it used to be duplicated byte-for-byte inside `bash.nix`
  until they were merged here, because `home.file.<n>.text` is
  `types.lines` and **concatenates** across modules rather than overriding —
  two definitions of the "same" file meant every `ble-import` line ran
  twice. Also notable for keeping one script as a real file
  (`pkgs.writeText`) rather than an inline Nix string specifically because
  it's full of bash `${...}` parameter expansions that would each need
  escaping as `''${...}` inside a Nix `''` string otherwise — content read
  from disk is never touched by Nix's own interpolation at all. Full
  writeup, including the carapace/fzf/atuin integrations it wires together
  and an open upstream bug found in them: [blesh](blesh.md).
- **`shell-env/shell-env.nix`** — `homeManager`-only: `home.shellAliases`
  (the everyday `ll`, `cp -i`, `lcd`, `img-cat`, `kssh`, etc.), plus
  `home.sessionVariables` and `home.sessionPath`. Since 2026-08-24 it also
  carries the category's only platform-guarded content: a
  `lib.optionalAttrs pkgs.stdenv.isDarwin` block aliasing `discord` and
  `google-chrome` to `open -a …`. Those two are homebrew casks on lysithea,
  and a cask with no `binary` stanza installs a `.app` and nothing on PATH,
  so both stopped being commands there when `b0845be6` excluded the nix
  packages as unfree cask duplicates — a side effect that commit's
  evaluation-only verification could not see. The guard matters because this
  file is shared with the four Linux hosts, where `discord` and
  `google-chrome` already are the real binaries and an unguarded alias would
  shadow them with an `open` that doesn't exist. The file's own header has
  the full timeline.
- **`zsh/zsh.nix`** — `nixos`-class enables the shell and disables HM's
  `enableCompletion` with `mkForce false` ("unless disabled, home-manager
  causes an extra compaudit"); `homeManager`-class carries the actual
  283-line zsh config, plugins, and a troubleshooting note (`~/.zcompdump`/
  `~/.config/zsh/.zcompdump` deletion) right in the file for when "zsh side"
  errors show up.

## The `home.file`/`home.sessionPath` concatenation trap, live in this category

`blesh.nix`'s own header is the concrete example (not just the abstract
warning) behind the `home-manager-dotfiles` skill's top trap: `text`-typed
Home Manager options merge silently across every module that touches them,
so two modules writing what looks like the same file double it rather than
one overriding the other. Worth knowing before adding a second thing that
writes to `.blerc`, `.zshrc`, or similar in this category.

## Imported by

All four NixOS hosts directly. `lysithea` doesn't list `shell-config` in its
own imports, but reaches the `homeManager`-class content anyway (`bash`,
`blesh`, `shell-env`, `zsh`) via `nireUser/elly-home-manager.nix`'s shared
`ellyHomeManager` bundle, which every host's Home Manager config points at
regardless of what that host's own `nixos`/`darwin` import list says. System
shell *registration* on darwin (which shells exist in `/etc/shells`) is a
separate, platform-specific concern handled by [macos](../macos.md)'s
`shells.nix` instead.

## See also

- [blesh](blesh.md) — the `.blerc` config in full: what each
  `ble-import` wires up, and an open upstream bug (spurious `read: `':
  not a valid identifier` on Tab/auto-complete) traced into ble.sh's
  carapace/progcomp interaction.
- Skill `home-manager-dotfiles`
  (`.claude/skills/home-manager-dotfiles/SKILL.md`) — the general form of
  the concatenation trap above.
- [macos](../macos.md) — darwin-side shell registration.
- [../../architecture.md](../../architecture.md) — the `ellyHomeManager`
  bundle and why it, not per-host imports, is what actually reaches every
  host's home config.
