#!/usr/bin/env bash
# Weekly flake.lock bump, built on cube before a PR is proposed -- issue #205.
# Replaces .github/workflows/update-flake-lock.yml (deleted with the module
# that wires this): the GitHub runner could only EVALUATE a lock bump, and a
# bump that evaluates fine but breaks a host stays invisible until someone
# builds on real hardware -- lessons-learned §§36-37 are exactly this failure.
# Same Monday 09:00 UTC schedule, same update_flake_lock_action branch, same
# PR text; the token preflight and the failure/expiry issue-filing are ported
# from that workflow's steps.
#
# Runs as the flake-lock-bump systemd timer
# (config-system/homelab/lock-bump/). The token lives in secrets.yaml as
# `flake-lock-token`, decrypted to /run/secrets/flake-lock-token -- see
# wiki/maintenance-schedule.md item 10.
#
# `alert` mode (a separate unit, wired via OnFailure=): files into one
# reusable GitHub issue, what the workflow's notice step did. Necessary
# because a failed systemd timer notifies no one by itself -- a red Actions
# run at least emailed.
set -euo pipefail

repo_url="https://github.com/NireBryce/nixos-configs"
api_url="https://api.github.com/repos/NireBryce/nixos-configs"
branch="update_flake_lock_action"
state_dir="/var/lib/flake-lock-bump"
token_file="/run/secrets/flake-lock-token"
expire_warn_days=30
alert_title="update-flake-lock: weekly lock PR needs attention"

log() { printf '[lock-bump] %s\n' "$*"; }

# --------------------------------- alert mode --------------------------------
# Deliberately accepts an empty-issue-run too: this fires on ANY failure of
# the main unit, including "token was already dead", so it must not itself
# require more than the token file and gh.
if [[ "${1:-}" == "alert" ]]; then
    GH_TOKEN="$(cat "$token_file")"
    export GH_TOKEN
    journal="$(journalctl -u flake-lock-bump.service -n 40 --no-pager 2>&1 || true)"
    body="$(printf '%s\n' \
        "cube's \`flake-lock-bump\` run failed, or its GitHub token is within" \
        "${expire_warn_days} days of expiry -- the run opens the PR first and" \
        "only then exits non-zero on a near-expiry token, so a PR may still" \
        "have appeared this week." \
        "" \
        "If it is the token: mint a replacement fine-grained PAT scoped to" \
        "\`NireBryce/nixos-configs\` (\`Contents: read/write\`, \`Pull" \
        "requests: read/write\`), put it into \`secrets.yaml\` as" \
        "\`flake-lock-token\` with \`sops\` from a session that can decrypt," \
        "then switch cube. Details: \`wiki/maintenance-schedule.md\` item 10." \
        "" \
        "Last journal lines:" \
        "" \
        "\`\`\`" \
        "$journal" \
        "\`\`\`")"
    existing="$(gh issue list --state open \
        --search "\"${alert_title}\" in:title" --limit 1 \
        --json number --jq '.[0].number')"
    if [[ -n "$existing" ]]; then
        gh issue comment "$existing" --body "$body"
        log "commented on existing issue #${existing}"
    else
        gh issue create --title "$alert_title" --body "$body"
    fi
    exit 0
fi

# ------------------------------ token preflight ------------------------------
# Ported from the workflow's preflight step: fail fast and legibly on a dead
# token instead of after the flake update, and warn inside 30 days of expiry.
# GitHub sends `github-authentication-token-expiration` only for tokens that
# HAVE an expiry, so an absent header means "cannot tell", not "healthy".
token="${FLAKE_LOCK_TOKEN:-}"
if [[ -z "$token" && -r "$token_file" ]]; then
    token="$(cat "$token_file")"
fi
if [[ -z "$token" ]]; then
    log "ERROR: no token: \$FLAKE_LOCK_TOKEN unset and ${token_file} unreadable"
    exit 1
fi

headers="$(curl -sS -D - -o /dev/null \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github+json" \
    "$api_url")"
status="$(printf '%s' "$headers" | awk '/^HTTP/{code=$2} END{print code}')"
if [[ "$status" != "200" ]]; then
    log "ERROR: token rejected: GitHub answered HTTP ${status} for ${api_url} -- expired, revoked, or no longer scoped to this repo"
    exit 1
fi
expiring=0
expiry="$(printf '%s' "$headers" | tr -d '\r' \
    | awk -F': ' 'tolower($1)=="github-authentication-token-expiration"{print $2}')"
if [[ -n "$expiry" ]]; then
    now="$(date -u +%s)"
    then_ts="$(date -u -d "$expiry" +%s 2>/dev/null || true)"
    if [[ -n "${then_ts:-}" ]]; then
        days=$(( (then_ts - now) / 86400 ))
        log "token expires ${expiry} (${days} days)"
        if (( days <= expire_warn_days )); then
            log "WARNING: token expires in ${days} days -- this run still opens its PR if it gets that far, but mint a replacement (see wiki/maintenance-schedule.md item 10)"
            expiring=1
        fi
    else
        log "notice: expiry header '${expiry}' unparsable; early warning is best-effort"
    fi
else
    log "notice: no expiry header; cannot tell when this token lapses"
fi

GH_TOKEN="$token"
export GH_TOKEN

# ------------------------------- clone / refresh -----------------------------
checkout="${state_dir}/checkout"
if [[ ! -d "${checkout}/.git" ]]; then
    log "cloning into ${checkout}"
    git clone -q "$repo_url" "$checkout"
fi
cd "$checkout"
git fetch -q origin --prune
# Fresh base every run, whatever happened to last week's PR: merged, still
# open (this force-push updates it in place), or manually closed.
git checkout -q -B "$branch" origin/experimental

# ------------------------------- update the lock -----------------------------
log "nix flake update"
(cd flake && nix flake update)
if git diff --quiet -- flake/flake.lock; then
    log "flake.lock unchanged -- nothing to propose this week"
    exit 0
fi

# --------------------------------- preflight ---------------------------------
# The checks the workflow's PR text told a human to run, run here instead --
# plus the build, which is the entire point of moving this off the runner.
log "preflight: nix flake check (forces every toplevel as an evaluation)"
(cd flake && nix flake check --all-systems --no-build)
log "preflight: module tree checks"
(cd flake && python3 scripts/modules.py check modules)
log "preflight: lint ratchet"
(cd flake && python3 scripts/lint.py check)

log "build: nire-cube toplevel -- the part the runner structurally could not do"
nix build ./flake#nixosConfigurations.nire-cube.config.system.build.toplevel --no-link

# ------------------------------ commit / push / PR ---------------------------
git add -- flake/flake.lock
# Synthetic identity on purpose: this commit is a timer's output, and the
# lock diff is the review. Change it here if it ever wants to be a person.
git -c user.name="nire-cube lock-bump" \
    -c user.email="lock-bump@nire-cube.invalid" \
    commit -q -m "chore: update flake.lock"
git push -q --force origin "$branch"

open_prs="$(gh pr list --head "$branch" --state open --json number -q 'length')"
if [[ "$open_prs" != "0" ]]; then
    log "PR for ${branch} already open; branch force-updated in place"
else
    gh pr create --base experimental --head "$branch" \
        --title "chore: update flake.lock" --body "$(cat <<'BODY'
Automated weekly `nix flake update` (all inputs), targeting
`experimental`.

The lock diff is the review: this repo pins nixpkgs deliberately, and an
input bump can change what hosts build and boot. Check the diff and merge
through the normal ship flow when the change is wanted.

Unlike the Actions workflow this replaces (#205), this PR was only opened
after `nix flake check + module tree` went green AND nire-cube's toplevel
was **built** on cube -- CI still evaluates the other hosts. `just
preflight` plus a real `just build`/`switch` on each remaining host is
still the stronger check for those before merging.

Auto-opened by cube's flake-lock-bump timer; close unmerged if the timing
is wrong (mid-investigation, pre-boot-verification).
BODY
)"
fi

log "done"
if (( expiring )); then
    # After the PR, deliberately: the PR is the deliverable, the non-zero
    # exit is what trips OnFailure= into filing the expiry issue.
    log "exiting non-zero so OnFailure files the expiry issue"
    exit 1
fi
