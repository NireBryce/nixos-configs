---
name: guards-without-hooks
description: Runs a command through the repo's Bash guard hooks by hand when the harness does not run them.
when_to_use: Using a harness other than Claude Code or ZCode, a shell tool other than Bash, or unsure the guard hooks are active for a skill tagged Needs bash-guards.
---

# Running the guards by hand

## Applies to

The guard hooks in `.agents/hooks/` run only inside Claude Code and ZCode, and
only on their `Bash` tool. In any other harness (Codex, Gemini, Copilot,
Cursor, OpenCode, Pi, and the rest), or through any other shell tool, nothing
runs them, so the git, `just`, nix and sops protections are absent. A skill
tagged `**Needs:** bash-guards` relies on them.

The table in the book's [checks, guards and hooks](../../../book/src/agent-checks-and-guards.md#where-the-hooks-are-enforced)
chapter lists which harnesses enforce the hooks, with dates and evidence. A
harness not in it does not enforce them.

Skip this skill in Claude Code or ZCode with `Bash`: the harness already runs
the hooks, and running them again only repeats the output. It does not replace
the hooks either (see Limits).

## What to do

1. **Tell the user once, at the start**: this harness does not run the repo's
   guard hooks, so you will check commands by hand with `guard-check`, which
   protects less than the hooks do.
2. **Before each command that touches git state, `just`, a nix evaluation or
   build, `sops` or the deployed secrets**, run it through the helper instead
   of straight to the shell. The helper runs nothing itself:

   ```sh
   just agent guard-check -- '<the exact command, as one quoted string>'
   ```

   Without `just`: `python3 .agents/scripts/guard_check.py -- '<command>'`.
   Add `--cwd <dir>` when the command runs somewhere other than the current
   directory. The exit status tells you what to do:

   | Exit | Meaning | You |
   |---|---|---|
   | 0 | No hook objected (notes may print) | Run the command |
   | 2 | A hook denied it | Do not run it. Do what the reason says, usually ask the user |
   | 3 | A hook said ask | Stop and put the reason to the user; run it only on a yes in the chat |
   | 4 | A hook could not run (no `jq`, crash) | The command was not fully checked. Say so to the user before running it |

3. **Run the command only after that**, with the same string you checked.
   A changed command needs a new check.

## Limits

- **Nothing enforces the call.** An agent that skips it has no guard at all.
- **Pre-call hooks only.** The scan of command output for secrets, the Edit
  and Read guards, and the lesson reminders on edits have no manual form.
  Keep secret values out of output yourself (skill `secrets-hygiene`).
- **String matchers.** The hooks match command text, so a command built
  indirectly (`sh -c "$X"`, a script that runs git) is not seen. The real
  hooks have the same limit.
- **Needs `jq`.** The hooks fail visibly without it; exit 4 is that case.

## See also

`.agents/scripts/guard_check.py` (its header lists the exit codes); the
book's [checks, guards and hooks](../../../book/src/agent-checks-and-guards.md)
chapter for what each hook enforces.
