#!/usr/bin/env bash
# Did preflight pass -- and if not, which step and why -- in one line per
# step instead of preflight's few hundred. Replaces the
# `just preflight 2>&1 | grep -E "^OK|FAIL|all checks|..." | tail` agents
# kept hand-writing to skim it (skill ship, step 0).
#
# Runs the same steps in the same order, read from the `preflight` recipe
# itself (`just --show preflight`), so a step added there is picked up
# here with no edit. That read is verbatim -- `--show` does not apply
# `{{...}}` substitutions, and these lines are eval'd as printed -- so a
# preflight step must use literal paths (`@flake/scripts/x.sh`, like the
# recurring-test step), or the eval dies with `{{: command not found`.
# Found live, 2026-09-29, by this script failing exactly that way on a
# `{{scripts}}` step. Like preflight, stops at the first failure and then
# prints that step's last 30 lines. wiki-lint's REVIEW notes don't fail
# it; they're counted on its line so they aren't silently lost.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 2
log=$(mktemp)
trap 'rm -f "$log"' EXIT

mapfile -t steps < <(just --show preflight | sed -n 's/^    @//p')
[[ ${#steps[@]} -gt 0 ]] || { echo "no steps found in the preflight recipe"; exit 2; }

for step in "${steps[@]}"; do
    start=$SECONDS
    if eval "$step" >"$log" 2>&1; then
        notes=$(grep -c '^REVIEW' "$log")
        printf 'ok    %-44s %4ss%s\n' "$step" $((SECONDS - start)) \
            "$([[ $notes -gt 0 ]] && echo "  ($notes REVIEW notes)")"
        # A step can print a warn-only NOTE (hooks-path-note.sh) that does
        # not affect its exit code; without this it never survives the
        # brief -- which is the tool the ship skill actually runs.
        grep '^NOTE' "$log" | sed 's/^/      /' || true
    else
        printf 'FAIL  %s\n\n' "$step"
        tail -n 30 "$log"
        exit 1
    fi
done
echo "preflight passed: ${#steps[@]} steps"
