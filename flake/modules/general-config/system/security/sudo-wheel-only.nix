# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: The setuid sudo binary is executable by `wheel` only (mode 4510,
# root:wheel), so a service account or any other non-wheel user -- cube's
# `container`, the DynamicUser services -- can't reach sudo's own parser at
# all, rather than reaching it and being refused by sudoers. Added
# 2026-09-26. Nothing non-wheel here calls sudo; the user is in wheel
# (elly-user.nix).
{
    nixos = {
        security.sudo.execWheelOnly = true;
    };
}
