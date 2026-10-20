# ZCode desktop 3.15.3: workspace hook trust approval from the review prompt is never persisted

Written 2026-10-19 against ZCode desktop 3.15.3 (Electron 41.0.3, env=prod) on
Linux x86_64 (NixOS 26.11).

Paste-ready for <https://github.com/zai-org/feedback>. Everything below the
"Describe the bug" heading is the report; the last section ("Local notes —
drop before filing") is not part of the report.

**Not filed. Not to be filed on the strength of this file existing** — per
`AGENTS.md`, filing outside `NireBryce/nixos-configs` needs the user saying so
explicitly, in those words, for this specific report.

---

## Describe the bug

When project-scope hooks (the `hooks` block in `<workspace>/.zcode/config.json`)
change, the app shows a "hook has changed — review required" prompt and blocks
the hooks until they are trusted. On 3.15.3, approving from that prompt never
persists anything: no trust record is written, the hooks stay blocked, and the
identical review request is regenerated at every session start. The backend
grant path works when invoked directly (see workaround), so the prompt's
approve action appears to never reach the trust coordinator.

In our case the trigger was the 3.15.3 config migration itself: on first run
after the upgrade it rewrote both `~/.zcode/cli/config.json` (reduced to
`{"hooks":{"events":{}}}`) and the workspace `.zcode/config.json` (adding
per-hook `"enabled": true` fields and two `"timeout": 60` entries) within the
same second (mtimes 23:22:16.99 and 23:22:17.00 local on 2026-10-18). That
changed the workspace hook bundle digest, and the app has demanded a re-review
ever since. We cannot confirm the in-prompt approval ever completed on this
install: the trust store file `~/.zcode/security/workspace-hook-trust-v1.json`
did not exist at all until we granted manually, and every observed review
request carried `generation: 1`.

## To Reproduce

1. Open a local git workspace whose `.zcode/config.json` contains a `hooks`
   block — ours has 12 command hooks across `SessionStart`, `PreToolUse` (three
   matcher groups) and `PostToolUse` (two matcher groups), all invoking scripts
   via `"$CLAUDE_PROJECT_DIR/..."`.
2. Upgrade to 3.15.3 and let the config migration rewrite the file (any other
   bundle digest change should do the same).
3. Start a session. The app reports the hooks are pending workspace trust and
   shows the review prompt ("hook has changed, review required").
4. Approve / trust the hooks through the prompt.
5. Restart the app or start a new session: the same review request appears
   again, and the hooks are still blocked.

## Expected behavior

Approving from the review prompt persists the approval to the persistent trust
store (`~/.zcode/security/workspace-hook-trust-v1.json`), the hooks run in
subsequent sessions, and the prompt does not reappear for the same bundle.

## Actual behavior

The prompt's approval produces no observable effect — no persisted record, no
telemetry, not even a failure event — and the review request is regenerated
identical on every session start:

- Three `workspace_hook.review_request_created` telemetry events over two days
  (sessions `sess_f306424e…` 03:20:08Z, `sess_48d4c06d…` 04:25:02Z,
  `sess_b76d5ce8…` 04:25:57Z on 2026-10-19), all with the same
  `workspaceIdentityDigest` (`b5c51c356901`) and `bundleDigest`
  (`781a1f2cd4ab5e53fd72335fdf24dc38016452a3fd8fb39ded3d0034acd86401`), all
  `generation: 1`, `requestItemCount: 12`, `requestEnabledCount: 12`.
- Twenty `config.project_hooks.pending_trust` warnings in the 2026-10-19 log
  alone (`diagnosticCode: config_project_hooks_pending_trust`, severity
  warning), emitted at each config evaluation.
- No approval-side or failure-side event of any kind: none of
  `workspace_hook.trust_selected`, `workspace_hook_review_settled`,
  `workspace_hooks_trusted_persistent`, and not even
  `workspace_hooks_interaction_timeout`. Whatever the prompt did on click, it
  produced no backend event.
- No approval persisted anywhere: `~/.zcode/cli/db/db.sqlite` tables
  `local_setting` and `permission` both have 0 rows; `~/.zcode/security/` was
  empty; `~/.zcode/v2/setting.json` contains no trust-related keys.

Sample log lines (`~/.zcode/cli/log/zcode-2026-10-19.jsonl`):

```json
{"event":"config.project_hooks.pending_trust","module":"adapters.config","message":"Project hooks pending workspace trust","context":{"configPath":"<workspace>/.zcode/config.json","configScope":"project","diagnosticCode":"config_project_hooks_pending_trust","diagnosticMessage":"Project hooks are pending workspace trust and remain blocked","diagnosticPath":"hooks","severity":"warning"}}
{"event":"workspace_hook.review_request_created","module":"workspace_hook_trust","message":"Workspace Hook Trust telemetry","context":{"workspaceIdentityDigest":"b5c51c356901","bundleDigest":"781a1f2cd4ab","generation":1,"requestItemCount":12,"requestEnabledCount":12}}
```

(The `bundleDigest` in the telemetry is a 12-char prefix; the full digest is
`781a1f2cd4ab5e53fd72335fdf24dc38016452a3fd8fb39ded3d0034acd86401` and stayed
constant throughout, so this is not a flapping-config loop.)

## Environment

- ZCode desktop 3.15.3 (Electron 41.0.3), production build, Linux x86_64
  (NixOS 26.11), installed via Nix.
- Workspace: a local git repository; project-scope hooks only (user-scope
  `~/.zcode/cli/config.json` has an empty `hooks.events`).

## Workaround (also proof the backend works)

The grant command documented in the app's own pending-trust diagnostic works
when invoked directly, and immediately persisted all 12 records (state became
`workspace_hooks_trusted_persistent`, store file created with 12 records):

```sh
ELECTRON_RUN_AS_NODE=1 <install>/ZCode/zcode \
  <install>/ZCode/resources/glm/zcode.cjs \
  hooks trust grant --workspace <workspace-path> --all-current \
  --bundle-digest 781a1f2cd4ab5e53fd72335fdf24dc38016452a3fd8fb39ded3d0034acd86401
```

## Additional context

1. **The documented CLI path does not work while the app is running.** Running
   `zcode hooks trust status` from a shell does not execute the command: the
   single-instance lock hands the argv to the running GUI (the second process
   registers deep links and exits; no command output, observed twice). The
   `ELECTRON_RUN_AS_NODE` + direct `zcode.cjs` invocation above is the only way
   we found to run it — undocumented, and unguessable for a normal user. Either
   the main process should dispatch `hooks` to the runtime, or the
   single-instance forward should handle it. (In the app bundle the
   main-process command switch handles `commands`, `plugin(s)`, `skills`,
   `tui`, `login`; `hooks` lives on a separate runtime entry
   (`runZCodeProtocolCommand`), which is presumably why the shell invocation
   falls through to app boot.)
2. Suspected area: the renderer→main wiring for the review interaction. A
   click produces no telemetry and no persisted state, so either the button's
   IPC target is missing in 3.15.3, or the prompt considers the request stale
   and silently drops the response. The full event vocabulary exists in the
   bundle (`trust_selected`, `review_settled`, `interaction_timeout`,
   `stale_response`, `trusted_persistent`), but none of these fired during any
   of the user's approve attempts.

---

## Local notes — drop before filing

- Manually granted 2026-10-19 ~04:37 local via the workaround; store now has 12
  records. App restart still pending to confirm the hooks actually execute
  in-app again (the running session had already bootstrapped an empty trust
  store; the trust coordinator loads records at bootstrap).
- Keep the migrated `.zcode/config.json` (per-hook `enabled: true`) — reverting
  it to the committed version would change the bundle digest again and re-trigger
  the review.
- If maintainers want logs: `~/.zcode/cli/log/zcode-2026-10-18.jsonl` and
  `zcode-2026-10-19.jsonl` contain every event quoted above. Trim to the
  quoted events before attaching.
- Honest uncertainty, worth keeping in the report's framing: first observed
  review request is already post-migration, so we cannot say whether in-prompt
  approval ever worked on this install — only that it did not work across at
  least three sessions on 3.15.3, and that nothing (including failure
  telemetry) was ever written.
