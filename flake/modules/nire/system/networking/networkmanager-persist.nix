# The persistence half of wifi.nix. wifi.nix only sets
# networking.networkmanager.enable; this is filed as its own sibling rather
# than folded in, matching tailscale-persist.nix's split from tailscale.nix.
#
# /var/lib/NetworkManager/secret_key encrypts the secrets NetworkManager
# stores for its connections. /etc/NetworkManager/system-connections IS
# persisted already (WARN-impermanence.nix's directories list), but the key
# that encrypts what's in it was not -- so on a host that wipes /, every boot
# got a fresh key while the encrypted secrets alongside it stayed keyed to the
# one before. Found 2026-08-22 via root-drift.sh flagging secret_key as
# real (non-cosmetic) drift.
#
# Filed beside wifi.nix rather than in the impermanence category, following
# the convention WARN-impermanence.nix states: persistence for state that
# only matters to one thing lives next to what generates it. Being a sibling
# also means the same category (`system`, imported whole by every Linux host)
# collects it, so it reaches exactly the hosts wifi.nix reaches.
#
# GUARDED the same way and for the same reason as tailscale-persist.nix:
# `system` is imported by nire-cube too, which has no impermanence -- see
# WARN-impermanence.nix's absence there (CLAUDE.md, Safety). An unguarded
# entry on a host that never wipes / would be a same-filesystem bind mount
# rescuing state from a wipe that never happens, plus a spurious "Neither
# /var/lib/nixos nor any of its parents are persisted" warning the moment ANY
# environment.persistence entry exists without it alongside.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, lib, ... }:
            lib.mkIf (config.boot.initrd.systemd.services ? restore-root) {
                environment.persistence."/persist".files = [ "/var/lib/NetworkManager/secret_key" ];
            };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-26 — first real activation on nire-tenacity hit impermanence's
# own guard
#
# `just switch` failed with "A file already exists at
# /var/lib/NetworkManager/secret_key!". Not a bug in this file: NetworkManager
# had already generated a live secret_key on the running boot (dated a day
# after /persist/var/lib/NetworkManager/ itself was created, from an earlier
# partial attempt), and impermanence's `files` activation refuses to silently
# bind-mount over a real file that's already sitting at the target -- it can't
# know whether to keep the live one or discard it, so it stops rather than
# guess wrong the way Grafana's secret_key module guards against re-rotating
# on top of `grafana.nix`, above -- same shape, unrelated file. Fixed by hand,
# once, the same way that file's header describes for itself: moved the live
# key into persistent storage rather than letting the activation invent a
# fresh one --
#
#     sudo mkdir -p /persist/var/lib/NetworkManager
#     sudo mv /var/lib/NetworkManager/secret_key /persist/var/lib/NetworkManager/secret_key
#
# -- then re-ran `just switch`, which succeeded. Confirmed after: the live
# path and the /persist copy are the same inode (`stat -c '%d %i'` on both
# matched), and the key's mtime was unchanged, so the wifi secrets already
# encrypted with it in `/etc/NetworkManager/system-connections` stayed
# decryptable rather than getting silently orphaned by a fresh key. This is a
# one-time migration step for whichever host activates this module's
# persistence entry for the first time, not something the module itself
# should try to automate -- moving a file on someone's behalf during
# activation is exactly the silent-overwrite impermanence's guard exists to
# prevent.
