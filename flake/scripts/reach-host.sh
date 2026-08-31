#! /usr/bin/env bash
# Resolves a short host name (durandal/tenacity/cube/lysithea) to whichever
# of its real names actually answers, then execs ssh at it -- so reaching a
# host doesn't require remembering networking.hostName vs. the tailnet's own
# device name, or debugging Tailscale when the actual fix is to use the
# other name.
#
# WHY THIS EXISTS: 2026-08-30, a session ssh'd to `ts-cube` (the tailnet
# name, correctly recalled from this wiki's own trap writeup -- see
# wiki/traps-and-skills.md and this file's own header for the two OTHER
# traps this exact confusion has produced before) and got a plain resolution
# failure, because Tailscale itself wasn't connected on the CLIENT machine.
# Several turns went into diagnosing Tailscale's own health (`tailscale
# status`, whether the app was even running) before trying `nire-cube.local`
# -- which was reachable the entire time over plain LAN mDNS/Avahi and needs
# no Tailscale at all. A resolution failure (NXDOMAIN-shaped: "could not
# resolve hostname") means try the OTHER name, not diagnose the resolver.
#
# Tries, in order, the first one that accepts a real SSH connection:
#   1. nire-<host>.local            -- mDNS/Avahi, LAN-only, no Tailscale
#   2. ts-<host>.moose-micro.ts.net -- the tailnet name, works off-LAN too
#   3. nire-<host>                  -- last resort, in case plain DNS has it
#                                       somewhere neither of the above does
#
#   reach-host.sh <host> [remote command...]   # connect (or run a command)
#   reach-host.sh --resolve <host>              # print the working name, don't connect
#
# <host> is whatever comes after "nire-"/"ts-" -- durandal, tenacity, cube,
# lysithea. Not validated against hosts.nix: this only ever tries three
# derived DNS names and lets ssh's own connection attempt be the judge, so a
# fifth host works the day it's added with no edit here.
set -euo pipefail

resolve_only=false
if [[ ${1:-} == --resolve ]]; then
    resolve_only=true
    shift
fi

host=${1:?usage: reach-host.sh [--resolve] <durandal|tenacity|cube|lysithea> [remote command...]}
shift || true

candidates=(
    "nire-${host}.local"
    "ts-${host}.moose-micro.ts.net"
    "nire-${host}"
)

probe() {
    # A real (cheap) SSH handshake + auth, not just a DNS/ping check --
    # what this script promises is "ssh will actually work here", and a
    # name can resolve while nothing is listening or auth fails.
    ssh -o ConnectTimeout=3 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
        "$1" true >/dev/null 2>&1
}

working=""
for candidate in "${candidates[@]}"; do
    if probe "$candidate"; then
        working=$candidate
        break
    fi
done

if [[ -z $working ]]; then
    echo "reach-host.sh: none of these answered an SSH probe for '$host':" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    echo "Check the host is actually up, and that at least one of LAN/Tailscale is." >&2
    exit 1
fi

if $resolve_only; then
    echo "$working"
    exit 0
fi

echo "==> $host is reachable at $working" >&2
exec ssh "$working" "$@"
