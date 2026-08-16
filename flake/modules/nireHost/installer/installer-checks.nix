# Checks for the whole nire-installer feature, kept in this folder like
# everything else about it -- see installer-configuration.nix's header for
# why this directory groups a script/doc/config into modules/ rather than
# splitting across the usual modules//scripts//doc/ layout. Same shape as
# installer-iso.nix: no flake.modules.<class> attribute, only `perSystem`,
# so dirsAsCategory has nothing to collect here regardless.
#
# Everything here formalizes a check this session already did by hand with
# ad-hoc `nix eval`/`bash -n`/manual store-path inspection while building
# the Calamares and autoinstall features -- turned into `nix flake check`
# entries so the next change gets caught automatically instead of relying on
# someone remembering to re-run those by hand. None of it can confirm
# behavior on the real X270 (see liveusb-installer.md, "What this doc does
# not cover") -- these catch the class of bug that showed up as an eval
# error, a Python syntax error, or a silently-dropped/re-added wizard page,
# not "does it actually boot".
{ config, ... }:
{
    perSystem = { system, pkgs, lib, ... }:
    lib.optionalAttrs (system == "x86_64-linux") (
    let
        # x86_64-linux only, same reason checks.nix's own host checks and
        # installer-iso.nix's package are filtered the same way: nire-installer
        # is an x86_64-linux nixosConfiguration, no remote builder or binfmt
        # from aarch64-darwin to evaluate it against pkgs for.
        installerCfg = config.flake.nixosConfigurations.nire-installer.config;

        # Forces evaluation of exactly the options this session's manual
        # `nix eval` calls checked by hand after adding installer-calamares.nix
        # and installer-autoinstall-testbed.nix -- both of which merge into
        # flake.modules.nixos.installerConfiguration by literal name rather
        # than `imports`, which `just modules` cannot see (it only compares
        # module class + filename stem, never the attribute a file actually
        # declares -- see installer-calamares.nix's header). A typo'd
        # attribute name in either file would merge nothing, evaluate fine,
        # and build fine -- silently installing an image missing the feature
        # entirely. This is what actually catches that, by asserting the
        # options those files are supposed to have contributed are really
        # there on the merged config.
        installerOptionsAsserted =
            assert lib.assertMsg installerCfg.services.desktopManager.gnome.enable
                "services.desktopManager.gnome.enable is false -- installer-calamares.nix didn't merge, or was edited";
            assert lib.assertMsg installerCfg.services.displayManager.gdm.enable
                "services.displayManager.gdm.enable is false -- installer-calamares.nix didn't merge, or was edited";
            assert lib.assertMsg installerCfg.security.polkit.enablePkexecWrapper
                "security.polkit.enablePkexecWrapper is false -- installer-calamares.nix didn't merge, or was edited";
            assert lib.assertMsg installerCfg.programs.partition-manager.enable
                "programs.partition-manager.enable is false -- installer-calamares.nix didn't merge, or was edited";
            assert lib.assertMsg installerCfg.services.openssh.enable
                "services.openssh.enable is false -- installer-configuration.nix didn't merge, or was edited";
            assert lib.assertMsg installerCfg.networking.networkmanager.enable
                "networking.networkmanager.enable is false -- installer-configuration.nix didn't merge, or was edited";
            assert lib.assertMsg (installerCfg.systemd.services ? autoinstall-testbed)
                "systemd.services.autoinstall-testbed is missing -- installer-autoinstall-testbed.nix didn't merge, or was renamed";
            assert lib.assertMsg (installerCfg.environment.etc ? "nixos-configs")
                "environment.etc.\"nixos-configs\" is missing -- installer-configuration.nix didn't merge, or was edited";
            true;
    in {
        checks = {
            # Evaluation-only (no build): the assert above already ran by
            # the time this attribute is even reachable, so this exists to
            # give `nix flake check`'s summary a named line for it and to
            # make `just check`'s `--no-build` still catch it (an assert
            # failure is an eval error either way, `--no-build` or not).
            installer-options = pkgs.runCommand "installer-options-check"
                { inherit installerOptionsAsserted; }
                ''echo "$installerOptionsAsserted" > "$out"'';

            # Catches a Python-level syntax error in the file that replaces
            # calamares-nixos-extensions' own modules/nixos/main.py --
            # exactly the kind of error that would only otherwise surface at
            # wizard runtime, inside Calamares' own python-interface loader,
            # with nobody watching (see liveusb-installer.md's caveats on
            # the Calamares and autoinstall paths both).
            installer-calamares-main-py-syntax = pkgs.runCommand "installer-calamares-main-py-syntax"
                { nativeBuildInputs = [ pkgs.python3 ]; }
                ''
                    python3 -m py_compile ${./config/calamares-nixos-main.py}
                    touch "$out"
                '';

            # Pins down the trimmed sequence installer-calamares.nix's
            # header and calamares-settings.conf's own comment document --
            # see config/check-settings-conf.py for exactly what's asserted
            # and why each module belongs on its side of the line.
            installer-calamares-settings-conf = pkgs.runCommand "installer-calamares-settings-conf"
                { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ]; }
                ''
                    python3 ${./config/check-settings-conf.py} ${./config/calamares-settings.conf} | tee "$out"
                '';

            # build-liveusb.sh and the autoinstall script both actually run
            # unattended on real hardware with nobody watching -- shellcheck
            # catches the class of quoting/globbing bug that's invisible
            # until exactly the wrong moment. config/autoinstall-testbed.sh
            # is kept as a real file specifically so this can lint it
            # directly (installer-autoinstall-testbed.nix substitutes
            # @rootUuid@/@bootUuid@ into it with lib.replaceStrings, not Nix
            # string interpolation, for the same reason -- see that file).
            installer-shellcheck = pkgs.runCommand "installer-shellcheck"
                { nativeBuildInputs = [ pkgs.shellcheck ]; }
                ''
                    shellcheck ${./build-liveusb.sh} ${./config/autoinstall-testbed.sh}
                    touch "$out"
                '';
        };
    });
}
