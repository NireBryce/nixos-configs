# The handheld half of the desktop story: Jovian, Steam, and the TDP stack.
#
# Generic to handhelds -- machines with built-in controllers that occasionally
# launch a SteamOS session -- not specific to tenacity; a second handheld would
# import this too.
#
# The Plasma 6 desktop this drops back to lives in kde-base.nix, imported below.
# It used to be one `services.desktopManager.plasma6.enable = true` here, which
# gave the handheld a desktop session with no XWayland and none of the KDE
# applications; kde-base.nix's history block has the detail.
#
# Not moved to kde-base: sddm, the default session and autologin all come from
# Jovian's own modules/steam/autostart.nix, which sets defaultSession to
# "gamescope-wayland". That is the half of kde-desktop.nix this host must not
# have.
{ config, lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Bound out here, before the module body: inside it `config` is the
        # NixOS config and `config.flake.modules...` would not resolve. The body
        # below genuinely needs the inner one, for
        # `config.jovian.decky-loader.extraPackages`, so the two must not be
        # confused. See CLAUDE.md, "There are two different `config`s".
        kdeBase = config.flake.modules.nixos.kde-base;
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }: {
            # # description = "Jovian/SteamOS handheld: Steam session, decky, TDP control";
            imports = [
                inputs.jovian.nixosModules.default # I think this is instead of needing them as module args?
                kdeBase
            ];

            # `config.jovian.…`, not `inputs.jovian.…`: the Jovian flake exposes
            # only nixosModules/legacyPackages/overlays/checks/devShells, no
            # `decky-loader`. The intended referent is the module option this
            # same file sets below.
            systemd.services.decky-loader.environment.LD_LIBRARY_PATH =
              lib.makeLibraryPath
              config.jovian.decky-loader.extraPackages;

            jovian = {
                steam = {
                    enable = true;
                    autoStart = true;
                    desktopSession = "plasma";
                    user = "elly";
                };
                hardware.has.amd.gpu = true;

                decky-loader = {
                    enable = true;
                    extraPackages = with pkgs; [
                        # power-profiles-daemon
                        inotify-tools
                        libpulseaudio
                        coreutils
                        gamescope
                        gamemode
                        mangohud
                        pciutils
                        systemd
                        gnugrep
                        python3
                        gnused
                        procps
                        steam
                        gawk
                        file
                    ];
                    extraPythonPackages = pythonPkgs: with pythonPkgs; [
                        click
                    ];
                };
            };

            # DELETE THIS OVERLAY once nixpkgs carries handheld-daemon >= 4.1.12.
            #
            # hhd 4.1.10 -- what nixpkgs pins as of the 2026-08-07 bump -- opens
            # src/hhd/__main__.py with `import pkg_resources`. setuptools 81
            # deprecated that module and 83 removed it outright; the setuptools
            # in the store ships only _distutils_hack, distutils-precedence.pth
            # and setuptools itself. So hhd exits 1 on startup and systemd
            # restart-loops it every 10s.
            #
            # Not a config bug and not a missing dependency: nixpkgs lists
            # setuptools in both build-system and dependencies, and hhd's own
            # pyproject.toml asks for setuptools>=65.5.0 expecting pkg_resources
            # to come with it. The module is gone from setuptools, so neither
            # helps.
            #
            # It worked before the nixpkgs bump, which is the tell -- 26.05
            # carried a setuptools that still had pkg_resources. The journal has
            # hhd running its full plugin set (adjustor_smu, adjustor_ppd,
            # gpd_win_controllers, powerbuttond, controller_rgb) right up to the
            # reboot on 2026-08-10. Nothing to do with the stage-1 migration:
            # hhd is an ordinary stage-2 service.
            #
            # What is below is upstream's own fix, backported verbatim rather
            # than invented here. hhd master (4.1.12) replaced pkg_resources
            # with importlib.metadata and dropped setuptools from its runtime
            # dependencies entirely. Every replacement here is one of theirs, so
            # when nixpkgs catches up this deletes cleanly instead of having to
            # be reconciled.
            #
            # src/hhd/, not hhd/: pyproject.toml says
            # `[tool.setuptools.packages.find] where = ["src"]`, so the package
            # sits under src/ in the tree even though it imports as `hhd`.
            #
            # --replace-fail throughout, so a version that no longer matches
            # fails the build loudly rather than silently patching nothing.
            nixpkgs.overlays = [
                (final: prev: {
                    handheld-daemon = prev.handheld-daemon.overridePythonAttrs (old: {
                        postPatch = (old.postPatch or "") + ''
                            substituteInPlace src/hhd/__main__.py \
                                --replace-fail 'import pkg_resources' \
                                               'from importlib.metadata import entry_points' \
                                --replace-fail 'pkg_resources.iter_entry_points("hhd.plugins")' \
                                               'entry_points(group="hhd.plugins")' \
                                --replace-fail 'pkg_resources.iter_entry_points("hhd.i18n")' \
                                               'entry_points(group="hhd.i18n")' \
                                --replace-fail 'autodetect.resolve()' \
                                               'autodetect.load()' \
                                --replace-fail 'register.resolve()' \
                                               'register.load()'
                        '';
                    });
                })
            ];

            # needed for tdp adjustor
            boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

            # Persist hhd's real state, not WARN-impermanence.nix. Declared
            # here instead because that file is imported by both hosts and
            # only tenacity runs handheld-daemon; durandal has no reason to
            # carry a persistence rule for a daemon it never runs.
            # environment.persistence."/persist".directories is `listOf`, so
            # this and WARN-impermanence.nix's own entries concatenate --
            # matching how `environment.systemPackages` merges across files
            # everywhere else in this tree. It works even though this file
            # does not import the impermanence module itself: the option is
            # declared once wherever `inputs.impermanence.nixosModule` lands,
            # and any module in the same host's tree can set a value for it,
            # regardless of who imports whom. Assumes the host also imports
            # `boot`, which every handheld does today; a jovian host without
            # impermanence would need this guarded, not just added.
            #
            # CONFIG_DIR in hhd's __main__.py defaults to /etc/hhd regardless
            # of the --user flag this service passes -- that flag only feeds
            # get_context()'s permission lookup, not the write path. /etc/hhd
            # is not nix-managed, so without this it resets to whatever
            # root-blank froze every single boot: fan curves and TDP profiles
            # saved through hhd-ui reverted the moment the machine rebooted.
            # Found 2026-08-11 as "hhd fan curves don't persist".
            #
            # This protects state going forward, not retroactively -- nothing
            # already in /persist/etc/hhd, so whatever was set before this
            # landed needs setting once more after it does.
            environment.persistence."/persist".directories = [ "/etc/hhd" ];

            services.handheld-daemon = {
                # TDP control works. The old warning here said it was stuck in
                # nixpkgs (#347279); adjustor is part of handheld-daemon now.
                # Confirmed running 2026-08-11: five adjustor plugins loaded,
                # acpi_call in lsmod, TDP reset after a real suspend.
                enable = true;
                user = "elly"; # TODO: use flake-parts to make this declared centrally
                # Leave this on, despite the crashes it causes in a Plasma
                # session. Under Plasma the journal fills with OVRL D-Bus and GL
                # errors ending in "Overlay thread died", and hhd-ui dumps core
                # about three times per boot.
                #
                # That is expected, not a fault to chase: the overlay is a
                # *gamescope* overlay and only renders inside the Steam session.
                # In desktop mode it has nothing to attach to. Upstream treats
                # this as by design and there is no fix to wait for -- the
                # advice is to use the desktop app instead, which is the same
                # binary run directly.
                #
                # Turning it off is worse than the noise. This one flag gates
                # both uses (nixos/modules/services/hardware/handheld-daemon.nix):
                #
                #     environment.systemPackages = [ cfg.package ]
                #       ++ lib.optional cfg.ui.enable cfg.ui.package;
                #
                # so `false` removes the overlay from Game Mode *and* takes
                # hhd-ui off PATH in Plasma, losing the tool upstream points you
                # at. The daemon, TDP, controller, RGB and power button are all
                # unaffected by the overlay dying, and it is a thread inside hhd
                # rather than a unit, so `systemctl --failed` stays clean.
                #
                # Two control surfaces already work on the desktop: `hhd-ui`, and
                # a web UI on 127.0.0.1:5335.
                #
                # The coredumps are bounded by
                # nire/system/storage/coredump-limit.nix.
                ui.enable = true;
                adjustor = {
                    enable = true;
                    loadAcpiCallModule = true;
                };
            };
            
            systemd.services."power-profiles-daemon" = {
                enable = false; # conflicts with adjustor in hhd
            };
        };
}

# more examples:
# https://github.com/gradientvera/GradientOS/blob/adcc4892703dc2129fc8f16d0bce56c2146cd788/mixins/jovian-decky-loader.nix#L5
# https://github.com/ciarandg/portfolio/blob/a45bfbd2ba95148a6df6cfcbba62b3e814364d4c/content/posts/nixos-steam-box/index.md?plain=1#L81
