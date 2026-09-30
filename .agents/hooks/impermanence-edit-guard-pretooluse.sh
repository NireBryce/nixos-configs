#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit matcher). Warns when a file edit
# lands in one of the two places AGENTS.md's Safety section fences off:
# the impermanence tree (flake/modules/general-config/impermanence/ -- two
# of the three NixOS hosts import it and wipe /root on boot, and
# WARN-impermanence.nix inside it deletes the /root btrfs subvolume in
# initrd on every boot) and the host hardware modules
# (flake/modules/host-config/<host>/hardware/hardware-<host>.nix, where
# fileSystems/boot live). Every other guard in this directory watches the
# Bash tool only; before this one, an Edit tool call could rewrite the
# /root-rollback machinery with nothing but AGENTS.md's prose in the way.
#
# Warn-only systemMessage, deliberately neither a deny nor an "ask": unlike
# the Bash guards, most edits in these trees are legitimate maintenance --
# the point is that the Safety-section context (read WARN-impermanence.nix
# first, skill `impermanence-initrd` for how to read real disk state)
# reaches the transcript at write time instead of depending on the model
# having internalized AGENTS.md. systemMessage rather than
# permissionDecision "ask" for the same reason git-guard emits it: an ask
# is a silent no-op under an auto permission mode, while systemMessage
# always reaches the transcript.
#
# Known limits: path-matching only -- a Bash-tool edit (sed -i, tee) of
# these same files is the git/secrets guards' territory and does not trip
# this. Renames of the guarded trees need the patterns below updated; the
# fixture tests in flake/scripts/test_guards.py pin them.
set -euo pipefail

# No jq: say so (JSON built by hand) instead of allowing silently -- the
# same fail-visible rule as secrets-guard-pretooluse.sh's header.
if ! command -v jq >/dev/null 2>&1; then
    cat >/dev/null
    printf '%s\n' '{"systemMessage":"impermanence-edit-guard: jq not on PATH, so the path of this edit was NOT checked against the impermanence tree / host hardware modules. Install jq (packages-config/nix-utils/) to re-arm the guard."}'
    exit 0
fi

input=$(cat)
file_path=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[ -n "$file_path" ] || exit 0

reason=""
# The leading-`*/` forms match absolute paths -- the harness's Edit/Write/
# MultiEdit contract hands over an absolute file_path, and a `*` in a bash
# `case` glob crosses `/`. The bare forms cover a relative path being passed
# anyway (a future harness or hand-run test): they over-warn on an
# identically-shaped tree copied elsewhere, e.g. under /tmp, which is the
# right direction for a warn. A rename of the guarded trees must update
# these patterns and the fixtures in flake/scripts/test_guards.py -- the
# fixtures pin that the guarded paths exist on disk, not just the strings.
case "$file_path" in
    */flake/modules/general-config/impermanence/*|\
    flake/modules/general-config/impermanence/*)
        reason="This edit is in the impermanence tree. Two of the three NixOS hosts (nire-durandal, nire-tenacity) import it and wipe /root on boot; WARN-impermanence.nix deletes the /root subvolume in initrd every boot and needs root-blank to exist. Read AGENTS.md's Safety section and .agents/skills/impermanence-initrd/SKILL.md before changing anything near it -- and trust /proc/1/mountinfo over lsblk/findmnt when verifying, the shell's view of mounts can look wrong while being correct."
        ;;
    */flake/modules/host-config/*/hardware/*|\
    flake/modules/host-config/*/hardware/*)
        reason="This edit is in a host hardware module -- fileSystems and boot live here, and a wrong entry can make the next boot fail before anyone can intervene. AGENTS.md's Safety section asks for care here; prefer 'just boot' over 'just switch' for anything touching these files, so the running generation stays as the fallback."
        ;;
esac

[ -n "$reason" ] || exit 0
jq -n --arg reason "$reason" \
    '{ systemMessage: ("⚠️  PROTECTED-CONFIG EDIT: " + $reason) }'
exit 0
