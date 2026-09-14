# The handheld half of the desktop story: Jovian, Steam, and the TDP stack.
#
# Generic to handhelds -- machines with built-in controllers that occasionally
# launch a SteamOS session -- not specific to tenacity; a second handheld
# would import this too.
#
# The Plasma 6 desktop this drops back to lives in kde-base.nix, imported
# below. It used to be one `services.desktopManager.plasma6.enable = true`
# here, which gave the handheld a desktop session with no XWayland and none
# of the KDE applications; kde-base.nix's history block has the detail.
#
# Not moved to kde-base: sddm, the default session and autologin all come
# from Jovian's own modules/steam/autostart.nix, which sets defaultSession
# to "gamescope-wayland" -- the half of kde-desktop.nix this host must not
# have.
{ config, lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Bound out here, before the module body: inside it `config` is the
        # NixOS config and `config.flake.modules...` would not resolve, while
        # the body genuinely needs the inner one, for
        # `config.jovian.decky-loader.extraPackages` -- the two must not be
        # confused. See CLAUDE.md, "There are two different `config`s".
        kdeBase = config.flake.modules.nixos.kde-base;

        # Imported by name, not left to the category: `desktop-env` is never
        # imported whole (see tenacity-configuration.nix), so a sibling file is
        # reachable through nothing and `just modules` reports it as an orphan.
        # Naming it here is also what scopes it -- /etc/hhd persists exactly
        # where handheld-daemon runs, because the two arrive together.
        jovianPersist = config.flake.modules.nixos.jovian-persist;
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }: {
            # Jovian/SteamOS handheld: Steam session, decky, TDP control
            imports = [
                inputs.jovian.nixosModules.default # I think this is instead of needing them as module args?
                kdeBase
                jovianPersist
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

            # needed for tdp adjustor
            boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

            # hhd's own /etc/hhd state is persisted by jovian-persist.nix, a
            # sibling of this file -- without it, fan curves and TDP profiles
            # reset on every boot. Split out 2026-08-14; it was declared here
            # until then.

            services.handheld-daemon = {
                enable = true;
                user = "elly"; # TODO: use flake-parts to make this declared centrally
                # Leave this on, despite benign crashes it causes in a Plasma
                # session: the journal fills with OVRL D-Bus and GL errors
                # ending in "Overlay thread died", and hhd-ui dumps core about
                # three times per boot. Expected, not a fault to chase -- the
                # overlay is a *gamescope* overlay and only renders inside the
                # Steam session; in desktop mode it has nothing to attach to.
                # Upstream treats this as by design, there is no fix to wait
                # for -- the advice is to use the desktop app instead, the
                # same binary run directly.
                #
                # Turning it off is worse than the noise. This one flag gates
                # both uses (nixos/modules/services/hardware/handheld-daemon.nix):
                #
                #     environment.systemPackages = [ cfg.package ]
                #       ++ lib.optional cfg.ui.enable cfg.ui.package;
                #
                # so `false` removes the overlay from Game Mode *and* takes
                # hhd-ui off PATH in Plasma, losing the tool upstream points
                # you at. The daemon, TDP, controller, RGB and power button are
                # unaffected by the overlay dying, and it is a thread inside
                # hhd rather than a unit, so `systemctl --failed` stays clean.
                # Two control surfaces already work on the desktop: `hhd-ui`,
                # and a web UI on 127.0.0.1:5335.
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
#
# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-10 to 2026-09-13 -- the file carried an overlay backporting hhd
# master's fix onto nixpkgs' handheld-daemon 4.1.10: hhd opened
# src/hhd/__main__.py with `import pkg_resources`, setuptools 81 deprecated
# that module and 83 removed it outright, so hhd exited 1 on startup and
# systemd restart-looped it every 10s. Not a config bug and not a missing
# dependency -- the tell was that it worked before the 2026-08-07 nixpkgs
# bump: 26.05's setuptools still had pkg_resources, and the journal had hhd
# running its full plugin set right up to the 2026-08-10 reboot. The
# overlay replaced five strings with upstream 4.1.12's own
# importlib.metadata versions, --replace-fail throughout so a future
# mismatch would fail the build loudly. That failure arrived on schedule:
# nixpkgs carried 4.1.12 as of the 2026-09-11 lock bump (#308), the first
# --replace-fail matched nothing, and the tenacity build died in patchPhase
# -- CI had evaluated green, exactly the §§36–37 gap the pre-merge build
# exists for. Overlay deleted per its own instruction; upstream's fix is
# now in the package itself.
