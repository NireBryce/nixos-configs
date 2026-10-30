#!/usr/bin/env python3
"""Run a command through this repo's Bash guard hooks by hand.

The guard hooks in .agents/hooks/ fire only inside Claude Code and ZCode, and
only for their `Bash` tool. In any other harness nothing runs them. This
script is the manual substitute: it builds the PreToolUse payload a harness
would send, pipes it through every hook that settings.json attaches to the
`Bash` matcher, and reports what they said. Skill `guards-without-hooks` says
when an agent must call it.

  guard_check.py [--cwd DIR] [--session ID] -- '<command string>'

Pass the command as ONE quoted string; several words are joined with
shlex.join. Nothing is executed: the hooks only read the payload (git-guard
runs `git status`, the nix guard runs `git ls-files`; none changes anything).

The hook list comes from .agents/settings.json, so a hook added there is
checked here with no edit to this file. Exit status, the worst answer wins:

  0  no hook objected (notes and reminders may still print)
  2  at least one hook DENIED (or exited 2): do not run the command; do
     what the reason says, usually ask the user
  3  at least one hook said ASK: stop and put the reason to the user; an
     answer in the chat is the confirmation a harness prompt would have been
  4  a hook could not run (missing jq or interpreter, crash, bad JSON): the
     command was NOT fully checked; say so to the user before running it

Limits, stated so nobody trusts it past them: it is an honor system (the
agent has to call it, nothing makes it), it covers only the PreToolUse Bash
hooks (the post-call secrets output scan, and the Edit and Read guards, have
no manual form), and the hooks are string matchers, not a security boundary.
"""
import argparse
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SETTINGS = REPO / ".agents" / "settings.json"
HOOK_TIMEOUT = 30
CODES = {"deny": 2, "ask": 3, "error": 4}


def bash_pretooluse_hooks(settings_path=SETTINGS):
    """Hook command strings attached to the `Bash` matcher of PreToolUse,
    in settings order, with $CLAUDE_PROJECT_DIR expanded by the shell."""
    cfg = json.loads(Path(settings_path).read_text())
    out = []
    for group in cfg.get("hooks", {}).get("PreToolUse", []):
        matcher = group.get("matcher", "")
        if "Bash" not in matcher.split("|"):
            continue
        out += [h["command"] for h in group.get("hooks", [])
                if h.get("type") == "command"]
    return out


def payload(command, cwd, session):
    return json.dumps({
        "hook_event_name": "PreToolUse",
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": str(cwd),
        "session_id": session,
    })


def judge(name, proc):
    """(level, text) for one hook's finished process. level is one of
    allow, note, ask, deny, error."""
    if proc.returncode == 2:
        return "deny", (proc.stderr or proc.stdout).strip() or "exited 2"
    if proc.returncode != 0:
        return "error", (f"exited {proc.returncode}: "
                         f"{(proc.stderr or proc.stdout).strip()[:300]}")
    text = proc.stdout.strip()
    if not text:
        return "allow", ""
    try:
        reply = json.loads(text)
    except ValueError:
        return "error", f"printed something that is not JSON: {text[:200]}"
    hso = reply.get("hookSpecificOutput") or {}
    decision = hso.get("permissionDecision")
    reason = (hso.get("permissionDecisionReason")
              or hso.get("additionalContext")
              or reply.get("systemMessage") or "").strip()
    if decision == "deny":
        return "deny", reason
    if decision == "ask":
        return "ask", reason
    if reply.get("decision") == "block":
        return "deny", reply.get("reason", "").strip()
    return ("note", reason) if reason else ("allow", "")


def run_hooks(command, cwd, session, hooks=None, env=None):
    """[(hook name, level, text)] for the command, one entry per hook."""
    hooks = bash_pretooluse_hooks() if hooks is None else hooks
    env = {**os.environ, "CLAUDE_PROJECT_DIR": str(REPO), **(env or {})}
    body = payload(command, cwd, session)
    results = []
    for hook in hooks:
        name = Path(shlex.split(hook)[-1]).name
        try:
            proc = subprocess.run(
                ["bash", "-c", f"exec {hook}"], input=body, text=True,
                capture_output=True, env=env, cwd=str(cwd),
                timeout=HOOK_TIMEOUT)
        except (OSError, subprocess.TimeoutExpired) as e:
            results.append((name, "error", f"could not run: {e}"))
            continue
        level, text = judge(name, proc)
        # A hook that says it did NOT check (no jq) is an error, not a pass.
        if level == "note" and ("NOT checked" in text or "NOT run" in text):
            level = "error"
        results.append((name, level, text))
    return results


def exit_code(results):
    levels = {lvl for _, lvl, _ in results}
    for lvl in ("deny", "ask", "error"):
        if lvl in levels:
            return CODES[lvl]
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--cwd", default=os.getcwd())
    ap.add_argument("--session", default=f"guard-check-{os.getppid()}")
    ap.add_argument("command", nargs="+")
    args = ap.parse_args(argv)
    command = (args.command[0] if len(args.command) == 1
               else shlex.join(args.command))
    results = run_hooks(command, Path(args.cwd), args.session)
    for name, level, text in results:
        if level != "allow":
            print(f"{level.upper():5} {name}: {text}")
    code = exit_code(results)
    verdict = {0: "no hook objected", 2: "DENIED -- do not run it",
               3: "ASK -- put the reason to the user first",
               4: "NOT FULLY CHECKED -- tell the user before running it"}[code]
    print(f"guard-check: {len(results)} hooks, {verdict}")
    return code


if __name__ == "__main__":
    sys.exit(main())
