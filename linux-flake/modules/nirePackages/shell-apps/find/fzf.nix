{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            programs.fzf = {
                enable = true;
                enableZshIntegration = true;
                enableBashIntegration = true;
                enableFishIntegration = true;

                # Ctrl-R belongs to atuin. fzf keeps Ctrl-T and Alt-C.
                #
                # An empty command is the supported way to yield the binding --
                # home-manager's own description says so: "An empty string
                # disables the CTRL-R binding, which is the supported way to
                # yield CTRL-R to a history manager such as Atuin or McFly."
                # Not `programs.atuin.flags = [ "--disable-ctrl-r" ]`, which the
                # 2026-08 evaluation warning offers as the other half of the
                # same choice and would hand the key to fzf instead.
                #
                # Per shell, because that is how the option is shaped. Only the
                # three integrations enabled above are set; the module also
                # covers nushell, which this config does not turn on -- add it
                # here if that ever changes, or fzf will take Ctrl-R back on
                # that shell alone.
                historyWidget = {
                    bash.command = "";
                    zsh.command  = "";
                    fish.command = "";
                };
                defaultOptions = [
                    "--height 40%"
                    "--layout=reverse"
                    "--border"
                    "--inline-info"
                    #todo: fix these I think they only work for bash or its expecting `vivid`
                    # '' --color 'fg:#${vars.colors.base05}' ''              # Text
                    # '' --color 'bg:#''${vars.colors.base00}' ''              # Background
                    # '' --color 'preview-fg:#''${vars.colors.base05}' ''      # Preview window text
                    # '' --color 'preview-bg:#''${vars.colors.base02}' ''      # Preview window background
                    # '' --color 'hl:#''${vars.colors.base0A}' ''              # Highlighted substrings
                    # '' --color 'fg+:#''${vars.colors.base0D}' ''             # Text (current line)
                    # '' --color 'bg+:#''${vars.colors.base02}' ''             # Background (current line)
                    # '' --color 'gutter:#''${vars.colors.base02}' ''          # Gutter on the left (defaults to bg+)
                    # '' --color 'hl+:#''${vars.colors.base0E}' ''             # Highlighted substrings (current line)
                    # '' --color 'info:#''${vars.colors.base0E}' ''            # Info line (match counters)
                    # '' --color 'border:#''${vars.colors.base0D}' ''          # Border around the window (--border and --preview)
                    # '' --color 'prompt:#''${vars.colors.base05}' ''          # Prompt
                    # '' --color 'pointer:#''${vars.colors.base0E}' ''         # Pointer to the current line
                    # '' --color 'marker:#''${vars.colors.base0E}' ''          # Multi-select marker
                    # '' --color 'spinner:#''${vars.colors.base0E}' ''         # Streaming input indicator
                    # '' --color 'header:#''${vars.colors.base05}' ''          # Header
                ];
            };
        };
}
