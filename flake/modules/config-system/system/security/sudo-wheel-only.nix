# The setuid sudo binary is executable by `wheel` only (mode 4510,
# root:wheel), so a service account or any other non-wheel user -- cube's
# `container`, the DynamicUser services -- can't reach sudo's own parser at
# all, rather than reaching it and being refused by sudoers. Added
# 2026-09-26. Nothing non-wheel here calls sudo; the user is in wheel
# (elly-user.nix).
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "sudo executable by wheel only";
            security.sudo.execWheelOnly = true;
        };
}
