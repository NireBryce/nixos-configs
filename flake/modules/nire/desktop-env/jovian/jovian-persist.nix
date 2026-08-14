# The persistence half of jovian.nix. Split out 2026-08-14; until then this was
# a single `environment.persistence` block partway down that file.
#
# Filed beside jovian.nix, NOT in the impermanence category. That is deliberate,
# and it is what keeps the scoping: moving it under nire/impermanence/ would
# hand /etc/hhd to durandal too, which runs no handheld-daemon and has no reason
# to carry the rule.
#
# Being a sibling is NOT enough to make it reachable, though. `desktop-env` is
# never imported whole -- hosts name `jovian` directly -- so nothing collects
# this file, and `just modules` reported it as an orphan the moment it was
# created. jovian.nix imports it explicitly instead, which is also the tighter
# guarantee: the persistence rule cannot arrive without the daemon that needs
# it, or be forgotten by a host that adds one.
#
# environment.persistence."/persist".directories is `listOf`, so this and
# WARN-impermanence.nix's own entries concatenate -- matching how
# `environment.systemPackages` merges across files everywhere else in this tree.
# It works even though this file does not import the impermanence module itself:
# the option is declared once wherever `inputs.impermanence.nixosModule` lands,
# and any module in the same host's tree can set a value for it, regardless of
# who imports whom. Assumes the host also imports `impermanence`, which every
# handheld does today; a jovian host without it would need this guarded, not
# just deleted.
#
# CONFIG_DIR in hhd's __main__.py defaults to /etc/hhd regardless of the --user
# flag the service passes -- that flag only feeds get_context()'s permission
# lookup, not the write path. /etc/hhd is not nix-managed, so without this it
# resets to whatever root-blank froze every single boot: fan curves and TDP
# profiles saved through hhd-ui reverted the moment the machine rebooted.
# Found 2026-08-11 as "hhd fan curves don't persist".
#
# This protects state going forward, not retroactively -- nothing is already in
# /persist/etc/hhd, so whatever was set before this landed needs setting once
# more after it does.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            environment.persistence."/persist".directories = [ "/etc/hhd" ];
        };
}
