{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # Cod - Completion daemon
            # I think it needs to be system installed to access system shells
            environment.systemPackages = with pkgs; [
                cod
            ];
        };

        # Restored 2026-08-22 alongside carapace, after being removed
        # outright the same day -- see carapace-completions.nix's history
        # note for the original conflict this caused: bash's `complete -F`
        # is last-registration-wins per command, and cod's PROMPT_COMMAND
        # hook re-registers a command's completion function every time it
        # observes that command's `--help` being run, which clobbers
        # whatever carapace set up for the same name.
        #
        # Rather than dropping cod, this ignores every command carapace
        # already has a spec for, in cod's own config file
        # (~/.config/cod/config.toml, a `policy = "ignore"` rule per
        # executable -- `cod example-config` documents the format). The
        # list is generated from carapace's actual spec list at build time
        # below, not hand-copied, so it tracks carapace's coverage (~1000
        # commands as of 2026-08-22, and growing) instead of needing
        # maintenance here every time carapace adds one.
        #
        # This only has to handle cod *re*-learning a command carapace
        # already covers. It does not have to win the shell-startup
        # registration race by itself: bash.nix/zsh.nix source carapace's
        # own registration *after* cod's `cod init`, so carapace's bulk
        # `complete -F` naturally overwrites cod's for every name both
        # know at every shell startup, regardless of what is already in
        # cod's local ~/.local/share/cod/db.sqlite3 from before this rule
        # existed. The ignore rule only has to stop cod from winning that
        # race *again* later in the same session, when you next run
        # `<carapace-covered-command> --help`.
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            let
                # carapace --list needs no $HOME/network -- checked with
                # both stripped, in a shell matching what a Nix build
                # sandbox gives it -- so this is a legitimate, reproducible
                # build-time step, not something reaching outside the
                # sandbox.
                ignoreConfig = pkgs.runCommand "cod-carapace-ignore.toml" {
                    nativeBuildInputs = [ pkgs.carapace pkgs.jq ];
                } ''
                    carapace --list | jq -r '
                        keys[]
                        | "[[rule]]\nexecutable = \"" + . + "\"\npolicy = \"ignore\"\n"
                    ' > $out
                '';
            in {
                home.file.".config/cod/config.toml".source = ignoreConfig;
            };
}
