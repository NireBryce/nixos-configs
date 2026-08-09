{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {

        flake.modules.homeManager.${moduleName} = { config, pkgs, ... }: {
            # An index for `apropos` / `man -k`. Plain `man foo` needs none of this.
            #
            # Neither built-in option is usable here. `programs.man.generateCaches`
            # builds a buildEnv over every entry in home.packages and runs mandb at
            # *build* time, so touching any one of ~128 packages rebuilds the whole
            # index locally. It had been on only as a side effect -- fish's
            # generateCompletions sets it with mkDefault -- and left with fish.
            # `documentation.man.generateCaches` is the same shape at system scope
            # and only maps /run/current-system/sw/share/man, so it would pay that
            # cost and still miss /etc/profiles/per-user/<user>/share/man, where the
            # packages actually worth searching live.
            #
            # Instead: a mutable cache that mandb maintains incrementally. NixOS
            # already assumes this pattern -- its man_db.conf ends with
            # `MANDB_MAP /run/current-system/sw/share/man /var/cache/man/nixos`,
            # a mutable location nothing in nixpkgs ever populates.

            # man-db reads ~/.manpath as the per-user config. MANDB_MAP only says
            # where this hierarchy's index lives; the hierarchy needs no declaring,
            # since man-db finds ../share/man next to each PATH entry. Same single
            # line home-manager's own generateCaches writes, minus the store path.
            #
            # OWNERSHIP: this module owns .manpath. home.file.<n>.text is
            # types.lines, so also enabling programs.man.generateCaches would
            # concatenate rather than override, giving one hierarchy two MANDB_MAPs.
            home.file.".manpath".text = ''
                MANDB_MAP ${config.home.profileDirectory}/share/man ${config.xdg.cacheHome}/man
            '';

            # No --create, so this updates rather than rebuilding and only touches
            # pages that changed. --user-db keeps out of the root-owned system cache.
            systemd.user.services.mandb = {
                Unit.Description        = "Update the user man page index";
                Service = {
                    Type                = "oneshot";
                    ExecStart           = "${pkgs.man-db}/bin/mandb --user-db --quiet";
                };
            };

            systemd.user.timers.mandb = {
                Unit.Description        = "Weekly user man page index update";
                Timer = {
                    OnCalendar          = "weekly";
                    Persistent          = true;     # catch up if the machine was off
                    RandomizedDelaySec  = "1h";
                };
                Install.WantedBy        = [ "timers.target" ];
            };
        };
}
