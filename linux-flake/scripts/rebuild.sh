#!/usr/bin/env bash
# Dispatch build/boot/switch to the right nh subcommand for the target host.
#
#     rebuild.sh <build|boot|switch> <flake-dir> <host>
#
# Exists because `just build` on nire-lysithea used to run `nh os build`
# against a darwin host and fail in a way that named neither problem. The host
# default derives from `hostname` plus a matching *-configuration.nix, and
# lysithea-configuration.nix now exists, so the fallback that used to hide this
# (everything not a NixOS host became nire-durandal) stopped firing on
# 2026-08-12.
#
# Two questions, deliberately separate, because they fail for different
# reasons and the messages should say which:
#
#   what IS the host   whether the flake declares darwinConfigurations.<host>.
#                      Cheap -- that attrset is a plain attrset in
#                      nireHost/hosts.nix, so attrNames does not force any
#                      configuration. ~0.1s.
#
#   can we build it    uname. There is no remote builder and no binfmt here, so
#                      a darwin system builds only on darwin and a NixOS system
#                      only on Linux. Worth catching up front: the native error
#                      for this is long and points at a derivation rather than
#                      at the mistake.
set -euo pipefail

action=${1:?usage: rebuild.sh <build|boot|switch> <flake-dir> <host>}
flake=${2:?}
host=${3:?}

case "$action" in
    build|boot|switch) ;;
    *) echo "rebuild.sh: unknown action '$action' (want build, boot or switch)" >&2; exit 2 ;;
esac

if nix eval --raw --apply "cfgs: if cfgs ? \"$host\" then \"yes\" else \"no\"" \
        "${flake}#darwinConfigurations" 2>/dev/null | grep -q yes; then
    class=darwin
else
    class=nixos
fi

local_os=$(uname -s)

if [ "$class" = darwin ] && [ "$local_os" != Darwin ]; then
    echo "rebuild.sh: $host is a darwin host; build it on the Mac." >&2
    exit 1
fi
if [ "$class" = nixos ] && [ "$local_os" != Linux ]; then
    echo "rebuild.sh: $host is a NixOS host and this is $local_os." >&2
    echo "  No remote builder and no binfmt, so it cannot be built here." >&2
    echo "  Evaluation still works: just check, just modules, just diff." >&2
    exit 1
fi

if [ "$class" = darwin ]; then
    # nix-darwin has no boot generation -- there is no bootloader to stage a
    # generation into, and `nh darwin` offers only build and switch. Say so
    # rather than silently treating it as a switch, which would activate
    # something the caller asked NOT to activate yet.
    if [ "$action" = boot ]; then
        echo "rebuild.sh: nix-darwin has no 'boot' -- nothing stages a generation" >&2
        echo "  for next boot the way systemd-boot does. Use 'switch', or 'build'" >&2
        echo "  to check it compiles without activating." >&2
        exit 1
    fi
    exec nh darwin "$action" "$flake" --hostname "$host"
fi

exec nh os "$action" "$flake" --hostname "$host"
