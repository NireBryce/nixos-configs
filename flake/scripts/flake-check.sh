#!/usr/bin/env bash
# `just check`: `nix flake check --all-systems --no-build`, retried once
# when -- and only when -- it fails with the known secrets.yaml store race.
#
# The race (check.yml's header has the full account, 2026-08-25): on the
# GitHub runner, evaluating several sops-enrolled hosts intermittently died
# with `error: path '.../secrets.yaml' is not valid`. Never reproduced
# locally, never a defect in this repo. check.yml mitigates it twice: a
# warmup step, and this retry.
#
# Why the retry lives here and not in check.yml: CI runs `just preflight`
# (since 2026-09-29), and wrapping one step of that from the workflow would
# mean listing preflight's steps in the workflow again -- the hand-kept
# copy that change removed. Why it is gated on the error text rather than
# on CI: an unconditional retry doubles the minutes a genuine evaluation
# error costs, on every host and in every PR; gated, it is inert on
# anything but the race, so it needs no CI-only switch. If the race ever
# surfaces with a different message, that is a real failure here until
# the pattern below learns it -- visible, not silent.
set -uo pipefail

flake=${1:?usage: flake-check.sh <flake-dir>}
cd "$flake" || exit 2

log=$(mktemp)
trap 'rm -f "$log"' EXIT

run() {
    # nix writes its progress and errors to stderr; merged so tee can keep
    # a copy for the signature check while it still streams live.
    nix flake check --all-systems --no-build 2>&1 | tee "$log"
    return "${PIPESTATUS[0]}"
}

run && exit 0
rc=$?
if grep -qE "secrets\.yaml' is not valid" "$log"; then
    msg="nix flake check hit the known secrets.yaml store race (check.yml header); retrying once"
    if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::$msg"; else echo "==> $msg" >&2; fi
    sleep 5
    run
    exit $?
fi
exit "$rc"
