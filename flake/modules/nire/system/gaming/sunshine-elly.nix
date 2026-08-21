# Device-permission groups elly needs for sunshine.nix (next door) to actually
# work at runtime -- split out from that file because it edits the user
# account rather than the service, and from elly-user.nix because these groups
# exist only because sunshine does, not because of anything about the account
# itself. `extraGroups` is `listOf str`, so this merges by concatenation with
# elly-user.nix's own list rather than needing to live there -- no conflict,
# no override, just another module contributing to the same option.
#
# capSysAdmin (in sunshine.nix) only grants CAP_SYS_ADMIN -- it does not bypass
# the normal DAC permission checks on the device nodes below, so elly still
# needs to be a member of the groups that own them:
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { ... }: {
            users.users.elly.extraGroups = [
                "render" # /dev/dri/renderD* (root:render, 0660) -- VAAPI hardware encode.
                         # logind's dynamic per-seat ACLs (the "uaccess" udev tag) cover
                         # /dev/dri/card* for an active graphical session, but NOT the
                         # render nodes -- those need static group membership regardless
                         # of session state, which is exactly what a background encoder
                         # needs. Confirmed against every AMD host's actual GID (303) with
                         # `nix eval`, not assumed.
                "video"  # /dev/dri/card* (root:video, 0660) -- KMS screen capture. Likely
                         # already covered by logind's seat ACL while elly is logged in,
                         # but sunshine's user service is tied to graphical-session.target
                         # rather than guaranteed to inherit that ACL grant, so this is
                         # belt-and-suspenders rather than provably redundant.
                "uinput" # /dev/uinput (root:uinput, 0660) -- the virtual mouse/keyboard/
                         # controller sunshine creates to actually deliver Moonlight's
                         # input back to the session. This group is created by
                         # hardware.uinput.enable, which sunshine.nix sets automatically --
                         # nothing here declares it, only joins it. Without this, streaming
                         # would show video with no way to control the far end.
            ];
        };
}
