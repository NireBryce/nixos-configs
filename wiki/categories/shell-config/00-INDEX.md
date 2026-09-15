# `shell-config` — `config-system/shell-config/`

_Last modified: 2026-09-14_

## Contents

- [What's in it](#whats-in-it)
- [The `home.file`/`home.sessionPath` concatenation trap, live in this category](#the-homefilehomesessionpath-concatenation-trap-live-in-this-category)
- [`SSH_ASKPASS` is unset for sessions with no display](#ssh_askpass-is-unset-for-sessions-with-no-display)
- [Comments inside a `''` string ship into the dotfile](#comments-inside-a--string-ship-into-the-dotfile)
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

## `SSH_ASKPASS` is unset for sessions with no display

Both `bash.nix` and `zsh.nix` open their init with the same three lines:
if neither `DISPLAY` nor `WAYLAND_DISPLAY` is set, `unset SSH_ASKPASS`.

nixpkgs' `programs.ssh` module exports `SSH_ASKPASS` globally whenever
`services.xserver.enable` is true — which `kde-desktop` makes true on
durandal and cube — and offers no way to scope it to sessions that actually
have a display. Over plain SSH, anything that reaches for it (`git push`
against an HTTPS remote, say) crashes instead of falling back to a terminal
prompt, because `ksshaskpass` needs a Qt/X11 platform that isn't there.
Found 2026-08-26 on cube: `git push` died with `ksshaskpass died of signal 6`
before it ever asked for a username.

It is a no-op on a host that never had the variable set (tenacity, which
imports no xserver-enabling desktop) and in a real graphical session. The
duplication across the two shells is deliberate — they are separate init
files, and neither sources the other.

## Comments inside a `''` string ship into the dotfile

`#` inside a Nix `''` string is **shell text, not a Nix comment**: it is
emitted verbatim into whatever file the string becomes, and a reader of
`~/.bashrc` sees it on every shell start. This category is where that
matters most, since nearly every module here generates a dotfile.

It had gone wrong twice by 2026-09-14: once historically, when fourteen
lines of maintenance notes shipped into `~/.zshrc` (the incident
`module-style-guide.md` records), and again when the notes accumulated
back — `~/.bashrc` reached 44 comment lines out of 107 and `~/.blerc` 100
out of 121, including dated incident narrative and nixpkgs-module
archaeology. **Rationale for the `.nix` editor goes above the string;
inside it, keep only what a person reading the generated dotfile needs.**
`zsh.nix`'s aliases block carries a standing note to this effect.

## Imported by

`durandal`, `tenacity`, and `cube` -- all three NixOS hosts -- directly.
`lysithea` doesn't list `shell-config` in its
own imports, but reaches the `homeManager`-class content anyway (`bash`,
`blesh`, `shell-env`, `zsh`) via `users/elly-home-manager.nix`'s shared
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
  (`.agents/skills/home-manager-dotfiles/SKILL.md`) — the general form of
  the concatenation trap above.
- [macos](../macos.md) — darwin-side shell registration.
- [../../architecture.md](../../architecture.md) — the `ellyHomeManager`
  bundle and why it, not per-host imports, is what actually reaches every
  host's home config.
