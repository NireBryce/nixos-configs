#! /usr/bin/env bash
# Warn before a `switch` that changes glibc's version under running sessions.
#
#   glibc-guard.sh <flake-dir> <host>
#
# NixOS has one /etc for every process. A switch repoints /etc/pam.d at the
# new generation's PAM modules, but anything started before it -- the display
# manager, and every running session's lock screen -- still has the old glibc
# loaded, and reads /etc/pam.d fresh at each login or unlock. Modules built
# against a newer glibc need symbol versions the loaded one lacks, so dlopen
# fails ("version `GLIBC_2.43' not found"), PAM drops them as faulty, and
# every authentication fails instantly.
#
# Hit on nire-durandal 2026-10-05/06, glibc 2.42 -> 2.44: the lock screen
# retried authentication every ~3 s on each resume (it looked like a key
# spamming Return; only `loginctl unlock-sessions` got out), and after the
# next switch SDDM's greeter crash-looped with "Module is unknown". Keeping
# the old libraries around does not help -- they were still in the store;
# what changes is the config the old processes read.
#
# Compares VERSIONS, not store hashes: a same-version glibc rebuild adds no
# symbol versions, so it does not break old processes. The new side is
# `pkgs.glibc.version` (an eval, ~1 s, no build). The running side is the
# glibc that /run/booted-system's and /run/current-system's pam_unix.so link
# against -- precisely the pairing that fails. booted covers the display
# manager and sessions from boot; current covers sessions started after an
# earlier switch.
#
# Warn-only: always exits 0, and says so when it cannot tell rather than
# staying silent. GLIBC_GUARD_BOOTED / GLIBC_GUARD_CURRENT override the two
# system paths for the tests (test_glibc_guard.py).
set -uo pipefail

flake=${1:?usage: glibc-guard.sh <flake-dir> <host>}
host=${2:?usage: glibc-guard.sh <flake-dir> <host>}
booted=${GLIBC_GUARD_BOOTED:-/run/booted-system}
current=${GLIBC_GUARD_CURRENT:-/run/current-system}

# glibc version (e.g. 2.42) that <system>'s pam_unix.so links against;
# empty when it cannot be determined.
pam_glibc() {
    local pam pkg
    pam=$(grep -ohE '/nix/store/[^ ]+/lib/security/pam_unix\.so' \
        "$1/etc/pam.d/login" 2>/dev/null | head -1)
    [ -n "$pam" ] || return 0
    pkg=${pam%/lib/security/pam_unix.so}
    nix-store -q --references "$pkg" 2>/dev/null \
        | sed -nE 's|^/nix/store/[a-z0-9]{32}-glibc-([0-9]+\.[0-9]+)-[0-9]+$|\1|p' \
        | head -1
}

new=$(nix eval --raw "$flake#nixosConfigurations.$host.pkgs.glibc.version" 2>/dev/null)
if [ -z "$new" ]; then
    echo "glibc-guard: could not evaluate the new glibc version; not checked." >&2
    exit 0
fi

stale=()
seen=""
for sys in "$booted" "$current"; do
    [ -e "$sys" ] || continue
    real=$(readlink -f "$sys")
    case " $seen " in *" $real "*) continue ;; esac
    seen="$seen $real"
    old=$(pam_glibc "$sys")
    if [ -z "$old" ]; then
        echo "glibc-guard: could not read the glibc behind $sys; not checked." >&2
        continue
    fi
    [ "$old" = "$new" ] || stale+=("$(basename "$sys" | sed 's/-system$//') $old")
done

[ "${#stale[@]}" -eq 0 ] && exit 0

{
    echo
    echo "WARNING: glibc changes to $new; running processes use:"
    for s in "${stale[@]}"; do echo "    $s"; done
    echo "  After this switch, login and unlock FAIL for anything started before"
    echo "  it: the lock screen loops, and SDDM's greeter crash-loops."
    echo "  Safer: Ctrl-C now, then \`just boot\` and reboot."
    echo "  If you switch anyway: log out and back in, then"
    echo "  \`sudo systemctl restart display-manager\`, BEFORE anything locks"
    echo "  (suspend locks). \`loginctl unlock-sessions\` gets out of a stuck lock."
    echo
} >&2
exit 0
