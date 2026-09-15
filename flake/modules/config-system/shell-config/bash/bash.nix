{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.pathsToLink = [
            "/share/bash-completion"
            ];
            environment.shells = with pkgs; [
            bash
            ];
        };
        
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            let
                # A real file rather than inlined, same reasoning as
                # blesh.nix's carapaceDescBash: it does textual surgery on
                # carapace's own generated function via ${...} parameter
                # expansions, and every one would need ''${...} escaping
                # inside a Nix '' string.
                carapaceCompleterReadFix = pkgs.writeText "carapace-completer-read-fix.bash"
                    (builtins.readFile ./carapace-completer-read-fix.bash);
            in {
            # bash line editor, allows zsh-like line editor tricks and bindings
            home.packages = with pkgs; [
                blesh
            ];
            # .blerc is owned by blesh.nix; this file used to declare a
            # byte-identical copy, which concatenated rather than overrode.

            programs.bash = {
                enable = true;
                enableCompletion = true;
                enableVteIntegration = true;

                #? Shell integrations go here but main bash config is in the system one.
                sessionVariables = {
                };
                shellAliases = {
                };
                #? Extra commands that should be run when initializing an interactive shell.
                #
                # Split into three ordered pieces rather than one block. ble.sh
                # has to be loaded FIRST and attached LAST, and everything else
                # -- kitty, dircolors, bash-preexec/atuin, the VTE
                # PROMPT_COMMAND rewrite, direnv, starship, zoxide -- has to
                # land in between. It was one plain block, which put ble-attach
                # ahead of all seven: nothing enforced that order, every one of
                # those modules also writes a plain `programs.bash.initExtra`
                # with no mkOrder, so `types.lines` merged them by module
                # evaluation order. It worked by accident, never by choice.
                #
                # Attaching early strands direnv's hook in the raw
                # PROMPT_COMMAND, outside ble.sh's management:
                #
                #   as shipped     PROMPT_COMMAND = [_direnv_hook]
                #   attach last    PROMPT_COMMAND = []          <- absorbed
                #
                # with both giving blehook PRECMD = bash-preexec hook + starship.
                #
                # mkBefore is order 500, a plain definition is 1000, mkAfter is
                # 1500. The attach needs to beat all of them:
                #
                #   mkAfter (1500)  direnv, starship and zoxide are also >=1500,
                #                   so it tied and lost on module evaluation
                #                   order -- all three still ran after attach
                #   mkOrder 2000    beat direnv and starship, still tied with
                #                   zoxide, which is itself `lib.mkOrder 2000`
                #                   (home-manager modules/programs/zoxide.nix:42)
                #
                # 2500 clears zoxide, the latest-ordered bash integration in
                # this config. Anything added later that also wants the last
                # word will need a number above this one -- check the merged
                # value, do not assume.
                initExtra = lib.mkMerge [
                    # nixpkgs' programs.ssh exports SSH_ASKPASS globally
                    # whenever services.xserver.enable is true (kde-desktop,
                    # so durandal and cube) with no way to scope it to
                    # sessions that have a display, and over plain SSH
                    # anything reaching for it dies instead of falling back
                    # to a terminal prompt -- ksshaskpass needs a Qt/X11
                    # platform that isn't there. zsh.nix carries the same
                    # three lines; wiki/categories/shell-config/00-INDEX.md
                    # has the incident. Notes live HERE, not inside the
                    # string below: `#` in a `''` string is shell text and
                    # ships into ~/.bashrc verbatim.
                    (lib.mkBefore ''
                        # No display: ksshaskpass would crash, prompt instead.
                        if [[ -z "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" ]]; then
                            unset SSH_ASKPASS
                        fi

                        [[ ''$- == *i* ]] && source -- ${pkgs.blesh}/share/blesh/ble.sh --attach=none
                    '')

                    # cod (packages/shell-apps/completions/cod-completions.nix
                    # provides it on PATH, nixos-class only) is broken on
                    # darwin -- nixpkgs: meta.broken = stdenv.hostPlatform.isDarwin
                    # -- and isn't imported there either way, so this would be
                    # command-not-found on nire-lysithea. Guarded the same way
                    # zsh.nix guards its own cod line.
                    #
                    # Must come *before* carapace's own source line below:
                    # bash's `complete -F` is last-registration-wins per
                    # command, cod's own PROMPT_COMMAND hook re-registers
                    # completions live on every `--help` run, and
                    # cod-completions.nix's ignore-list only stops cod from
                    # re-claiming a command carapace covers, not its *first*
                    # registration this session. Sourcing carapace after cod
                    # leaves carapace's bulk registration standing at shell
                    # startup for every command they both know.
                    (lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) ''
                        source <(cod init ''$''$ bash)
                    '')

                    # carapace (packages/shell-apps/completions/carapace-completions.nix
                    # provides it, home.packages, all platforms). Registers
                    # `complete -F _carapace_completer` for every command
                    # carapace has a spec for (~1000, `carapace --list`);
                    # unconditionally, no darwin guard needed.
                    #
                    # The read-fix source line must come right after this
                    # one: it patches _carapace_completer's own body, so it
                    # needs that function to already exist, and it needs to
                    # run before carapace-desc.bash's advice wraps the same
                    # function (from .blerc, when ble.sh attaches), so the
                    # advice ends up wrapping the patched version. See the
                    # fix file's own header and
                    # `wiki/lessons-learned.md` #39 for what it's
                    # working around.
                    ''
                        source <(carapace _carapace bash)
                        source ${carapaceCompleterReadFix}
                    ''

                    # Last. ble.sh absorbs the hooks every other integration
                    # installed, so this cannot move back into the block above.
                    # KONSOLE FOCUS-BELL FIX, and every part of its shape is
                    # load-bearing. konsole sends CSI I / CSI O on tab switch
                    # once anything enables mode 1004 focus reporting; ble.sh
                    # decodes those into synthetic keys `focus`/`blur` that no
                    # keymap of any version binds, so each one hits the
                    # decode-error path and rings both bells. Binding them to
                    # a no-op must happen IN READLINE and BEFORE ble-attach:
                    # synthetic-key names get keycodes assigned in
                    # first-registration order, so every ble-bind route that
                    # runs earlier (top-level .blerc, blehook ATTACH, a -C
                    # deferred callback -- all three tested) lands under a code
                    # that is later reassigned and silently stops matching,
                    # while pre-attach readline binds are imported by
                    # ble-attach after the tables are final, the same channel
                    # atuin's C-r rides. It cannot live in .blerc at all: ble.sh
                    # has already wrapped the bind builtin by the time it
                    # sources that. emacs keymap only -- bash is never in vi
                    # mode. Confirmed on hardware 2026-09-07; full account in
                    # wiki/categories/shell-config/blesh.md.
                    (lib.mkOrder 2500 ''
                        # Swallow konsole's focus/blur keys (see blesh.md).
                        if [[ -n "''${BLE_VERSION-}" ]]; then
                            __nire_focus_nop() { :; }
                            bind -m emacs -x '"\e[I": __nire_focus_nop'
                            bind -m emacs -x '"\e[O": __nire_focus_nop'
                        fi

                        [[ ! ''${BLE_VERSION-} ]] || ble-attach
                    '')
                ];
                # ? Extra commands that should be placed in {file}~/.bashrc.
                # ?   Note that these commands will be run even in non-interactive shells.
                bashrcExtra = '''';
                #? Extra commands that should be run when initializing a login shell.
                profileExtra = '''';
                #? Extra commands that should be run when logging out of an interactive shell.
                logoutExtra = '''';
            };
        };
}
