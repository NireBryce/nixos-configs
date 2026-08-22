# Wires Calamares into nire-installer, patched to install this flake's own
# target host (chosen at image-build time -- see NIRE_INSTALLER_TARGET_HOST
# below and liveusb-installer.md) instead of the generic configuration.nix it
# generates by default. See ./config/calamares-nixos-main.py and
# ./config/calamares-settings.conf, the two files this overrides in, for what
# actually changed and why.
#
# Confirmed by reading calamares-nixos-extensions' real source (vendored in
# nixpkgs, not fetched -- pkgs/by-name/ca/calamares-nixos-extensions/src):
# its `nixos` job module builds a template-substituted configuration.nix
# from wizard answers (locale/keyboard/hostname/user/package choices) and
# runs a plain, non-flake `nixos-install`. There is no config option to make
# it flake-aware -- the substitution is the whole mechanism -- so this
# overrides the package itself rather than configuring around it.
#
# Merges into flake.modules.nixos.installerConfiguration -- the same
# hardcoded literal name installer-configuration.nix declares (not the
# usual moduleName-derived pattern; see that file's own header for why an
# entry point doesn't follow it) -- rather than editing that file in place.
# Two files declaring the same attribute MERGE, per flake-parts' own
# mechanism (CLAUDE.md, "same-class same-name modules MERGE"); kept as a
# separate file so the override-chain code and its reasoning stay isolated
# and easily revertable, rather than doubling the length of an already
# heavily-commented installer-configuration.nix.
#
# `just modules` (flake/scripts/modules.py) CANNOT see this merge -- its
# collisions check only compares module class + filename stem, never the
# attribute name actually declared inside a file, so a typo here (e.g.
# `installerConfigurtion`) would merge nothing and fail silently rather than
# statically. Confirm after any edit here with, e.g.:
#     nix eval .#nixosConfigurations.nire-installer.config.security.polkit.enablePkexecWrapper
#     nix eval .#nixosConfigurations.nire-installer.config.services.desktopManager.gnome.enable
# both expected `true` -- neither `just modules` nor a bare eval-success
# would catch this attribute merging onto the wrong (or a new, orphaned)
# name.
{ ... }:
{
    flake.modules.nixos.installerConfiguration = { lib, pkgs, ... }:
    let
        # The flake attr Calamares' patched `nixos` job installs --
        # `nixos-install --flake path:/etc/nixos-configs#<this>`. Read only
        # via `nix build --impure` (build-liveusb.sh's own invocation), same
        # mechanism and same caveats as installer-autoinstall.nix's wifi
        # credentials: ordinary `nix eval`/`nix flake check`/`just modules`
        # run pure, where builtins.getEnv always returns "", so this is
        # always "" for every verification command already in use in this
        # repo, and main.py ends up substituted with an empty target -- eval-
        # safe, just not a working image, same as unset wifi creds. Only an
        # explicit `--impure` build with this actually set produces an image
        # that installs anything.
        targetFlakeAttr = builtins.getEnv "NIRE_INSTALLER_TARGET_HOST";

        # calamares-nixos-extensions' installPhase (unmodified, upstream's
        # own package.nix) ends with `runHook postInstall` -- this hook point
        # lets the two files below overwrite what installPhase's own `cp -r`
        # already produced, with no need to touch `src` or reimplement
        # installPhase ourselves.
        calamaresNixosExtensionsFlakeInstall = pkgs.calamares-nixos-extensions.overrideAttrs (oldAttrs: {
            postInstall = (oldAttrs.postInstall or "") + ''
                cp ${./config/calamares-settings.conf} $out/etc/calamares/settings.conf
                # settings.conf's modules-search line needs the *final* out
                # path, same reason upstream's own installPhase substitutes
                # this exact file -- our replacement source keeps the @out@
                # token for the same reason.
                substituteInPlace $out/etc/calamares/settings.conf --replace-fail @out@ $out

                cp ${./config/calamares-nixos-main.py} $out/lib/calamares/modules/nixos/main.py
                # @targetFlakeAttr@ is a plain textual token in main.py's own
                # source (not Nix interpolation -- see that file's header for
                # why), substituted here the same way installer-autoinstall.nix
                # substitutes @rootUuid@/@bootUuid@ into autoinstall.sh.
                substituteInPlace $out/lib/calamares/modules/nixos/main.py \
                    --replace-fail @targetFlakeAttr@ ${lib.escapeShellArg targetFlakeAttr}
            '';
        });

        # calamares-nixos is a plain callPackage-shaped function taking
        # calamares-nixos-extensions as an argument (it only uses it to build
        # the wrapped calamares binary's XDG_DATA_DIRS/XDG_CONFIG_DIRS) --
        # .override here is the standard nixpkgs mechanism, not a workaround.
        calamaresNixosFlakeInstall = pkgs.calamares-nixos.override {
            calamares-nixos-extensions = calamaresNixosExtensionsFlakeInstall;
        };

        # Reconstructs installation-cd-graphical-calamares.nix's inline
        # `calamares-nixos-autostart` by hand: that file defines it as a
        # plain `let` binding, not a top-level package, so there is nothing
        # to .override -- it has to be rebuilt pointed at the overridden
        # calamares-nixos above, the same way upstream builds it pointed at
        # the stock one.
        calamaresNixosAutostartFlakeInstall = pkgs.makeAutostartItem {
            name = "calamares";
            package = calamaresNixosFlakeInstall;
        };
    in {
        # Deliberately NOT importing installation-cd-graphical-calamares.nix
        # or -gnome.nix: both set environment.systemPackages to the STOCK,
        # unpatched calamares-nixos/-extensions/-autostart. That option
        # concatenates across files rather than overriding, so importing
        # either would install stock and patched Calamares side by side --
        # a real store-path collision risk (overlapping .desktop files, the
        # calamares binary itself), and genuinely ambiguous which
        # calamares.desktop autostart entry would win even if it didn't
        # collide. Instead, every option those two files set that's actually
        # load-bearing is hand-copied below; anything purely cosmetic in them
        # (GNOME favorites-bar tweaks, idle/suspend gsettings) is skipped --
        # cheap to add back later, not required for Calamares to work at all.

        # Required for calamares's own job modules and this override's
        # main.py, both of which shell out through pkexec.
        security.polkit.enablePkexecWrapper = true;
        # Required for kpmcore, the partition module's backend, to work.
        programs.partition-manager.enable = true;

        # installation-cd-graphical-base.nix (nire-installer's base, see
        # installer-configuration.nix) only sets services.xserver.enable --
        # no desktop manager, confirmed by reading that file directly. Without
        # this, nire-installer boots to a bare LightDM greeter with nothing
        # to log into, and Calamares has no desktop session to autostart in.
        # This was already wrong before Calamares entered the picture --
        # installer-configuration.nix's header and liveusb-installer.md both
        # claimed "GNOME live session," which wasn't true until this line.
        services.desktopManager.gnome.enable = true;
        services.displayManager.gdm = {
            enable = true;
            # autoSuspend would suspend the machine mid-install if nobody's
            # touched the keyboard in a while -- exactly wrong for an image
            # whose whole job is a possibly-long unattended install.
            autoSuspend = false;
        };
        # Matches upstream's own choice for this image: nobody's meant to be
        # remote-administering an installer session, they're standing in
        # front of the machine being installed.
        services.displayManager.autoLogin = {
            enable = true;
            user = "nixos";
        };
        # Calamares is a Qt app; this is upstream's own scaling fix for
        # running under a Wayland GNOME session rather than Xorg.
        environment.variables.QT_QPA_PLATFORM =
            ''$([[ $XDG_SESSION_TYPE = "wayland" ]] && echo "wayland")'';

        # No i18n.supportedLocales/glibcLocales here (upstream's Calamares
        # file sets both) -- both existed only to support the `locale` show
        # page, which calamares-settings.conf's trimmed sequence drops.

        environment.systemPackages = [
            calamaresNixosFlakeInstall
            calamaresNixosAutostartFlakeInstall
            calamaresNixosExtensionsFlakeInstall
        ];
    };
}
