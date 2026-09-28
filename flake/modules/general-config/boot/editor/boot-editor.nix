# No kernel command-line editing at the systemd-boot menu.
#
# nixpkgs defaults `editor` to true "for backwards compatibility", and its own
# option description recommends false: anyone at the console can append
# `init=/bin/sh` and boot straight into a root shell. On cube (no LUKS) that is
# the whole disk; on durandal and tenacity the LUKS passphrase still gates the
# root filesystem, but `rd.systemd.debug_shell` would give a root shell in
# initrd before it.
#
# The cost: recovery parameters (`boot.shell_on_fail`, `systemd.unit=`,
# `rd.break`) can no longer be typed at the boot menu. Add them to
# `boot.kernelParams` and rebuild, or boot an older generation, or a live USB.
#
# Named boot-editor, not editor.nix or boot.nix -- see boot-generations.nix's
# header for the same-name merge this avoids.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            boot.loader.systemd-boot.editor = false;
        };
}
