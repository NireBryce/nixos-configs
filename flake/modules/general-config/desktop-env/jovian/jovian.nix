# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: The handheld half of the desktop: Jovian, Steam, and the TDP stack.
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
# Not moved to kde-base: sddm and the default session are set below, not by
# Jovian's autostart.nix (jovian.steam.autoStart is off: it would SDDM-autologin
# into gamescope-wayland) -- the half of kde-desktop.nix this host must not
# have.
{ lib, inputs, ... }:
{
    # kde-base and jovian-persist by name: dirs-as-categories imports both into
    # this module. They were `config.flake.modules.nixos.<name>` bound in a
    # `let`, outside the module body, because the body genuinely needs the
    # inner (NixOS) `config` for `config.jovian.decky-loader.extraPackages`
    # and the two must not be confused; `includes` leaves no outer `config`.
    #
    # jovian-persist is imported by name, not left to the category: `desktop-env` is
    # never imported whole (see tenacity-configuration.nix), so a sibling file is
    # reachable through nothing and the orphan check reports it. Naming it here is
    # also what scopes it -- /etc/hhd persists exactly where handheld-daemon runs,
    # because the two arrive together.
    includes.nixos = [ "kde-base" "jovian-persist" ];

    nixos = { config, pkgs, ... }: {
        # Jovian/SteamOS handheld: Steam session, decky, TDP control
        imports = [
            inputs.jovian.nixosModules.default # I think this is instead of needing them as module args?
        ];

        # `config.jovian.…`, not `inputs.jovian.…`: the Jovian flake exposes
        # only nixosModules/legacyPackages/overlays/checks/devShells, no
        # `decky-loader`. The intended referent is the module option this
        # same file sets below.
        systemd.services.decky-loader.environment.LD_LIBRARY_PATH =
          lib.makeLibraryPath
          config.jovian.decky-loader.extraPackages;

        # The display manager used to arrive as a side effect of
        # jovian.steam.autoStart, which enabled SDDM with autoLogin into
        # gamescope-wayland. Enabled here instead, same settings minus the
        # autologin: a password at boot, Plasma as the default session,
        # Gaming Mode (gamescope-wayland) one click away -- Jovian's own
        # docs bless the display-manager path ("launch the Steam Deck UI
        # from your Display Manager"). kde-desktop.nix is durandal's
        # session module -- tenacity never had its own before this.
        services.displayManager = {
            defaultSession = "plasma";
            sddm = {
                enable = true;
                wayland.enable = true;
            };
        };

        jovian = {
            steam = {
                enable = true;
                # Not autoStart: that SDDM-autoLogins straight into the
                # gamescope session, which on a handheld is a pocketable
                # logged-in session whenever it sleeps in a bag. With it off
                # (the Jovian default), kde-desktop.nix's SDDM shows a real
                # greeter offering Gaming Mode (gamescope-wayland) and
                # Plasma; desktopSession has no effect in this mode and is
                # omitted. Wake-from-sleep protection is the screen lock's
                # job either way, not this option's.
                autoStart = false;
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

        # Jovian brings its own gamescope, and the security wrapper that
        # puts it first on PATH. gaming.nix's gamescopeSession.enable has
        # nixpkgs' steam module mkDefault programs.gamescope on, which
        # added nixpkgs' gamescope to systemPackages as a second, unused
        # build (until 2026-09-27). Durandal and cube keep theirs.
        programs.gamescope.enable = false;

        # needed for tdp adjustor
        boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

        # TEMPORARY -- works around a nixpkgs packaging bug; listed in
        # wiki/upkeep-and-admin/temporary-patches-and-hacks.md.
        #
        # Why: since the 2026-10-20 lock bump, nixpkgs signs kernel
        # modules with kmodigest at Kbuild's modules_install, leaving a
        # `<module>.ko.cer` beside each one, and the module aggregator
        # (pkgs/os-specific/linux/kmod/aggregator.nix) `cat`s that file
        # for every external module. acpi_call's installPhase copies the
        # .ko by hand and never runs modules_install, so no .cer exists
        # and the tenacity build dies in linux-<ver>-modules with
        #
        #     cat: misc/acpi_call.ko.cer: No such file or directory
        #
        # This runs kmodigest on the installed .ko, as modules_install
        # would. It is overridden in kernelPackages, not at the use
        # above, because nixpkgs' handheld-daemon module adds its own
        # `config.boot.kernelPackages.acpi_call` (adjustor.
        # loadAcpiCallModule) and both copies need the certificate.
        #
        # Remove when ALL of these hold:
        #   1. nixpkgs' acpi_call itself installs acpi_call.ko.cer -- the
        #      check below fails the build with a pointer here when it
        #      does, so an input bump announces it;
        #   2. with this block deleted, the tenacity toplevel builds
        #      (`just host=nire-tenacity build`; evaluation alone does not
        #      reach the modules aggregator);
        #   3. after switching, `modinfo acpi_call` resolves and hhd's TDP
        #      control still works (the adjustor is the only user).
        # Also remove it if tenacity stops carrying acpi_call at all.
        boot.kernelPackages = pkgs.linuxPackages.extend (kself: ksuper: {
            acpi_call = ksuper.acpi_call.overrideAttrs (old: {
                installPhase = old.installPhase + ''
                    ko=$out/lib/modules/${kself.kernel.modDirVersion}/misc/acpi_call.ko
                    if [ -e "$ko.cer" ]; then
                        echo "acpi_call now ships $ko.cer; delete the override in jovian.nix" >&2
                        exit 1
                    fi
                    ${lib.getExe pkgs.buildPackages.kmodigest} "$ko"
                '';
            });
        });

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
            # hardware-config/hardware/storage/coredump-limit.nix.
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
