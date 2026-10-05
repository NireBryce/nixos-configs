#!/usr/bin/env python3
"""PreToolUse hook (matchers `Bash` and `Edit|Write|MultiEdit`): puts the
one-line reminder for whatever .agents/lessons-map.toml topic the call
touches into the model's context, before the call runs (#460).

Most lessons in wiki/lessons-learned.md had `Enforced: none` -- they reached
an agent only if it chose to read the right skill first, and §5 records
that writing a trap down does not stop anyone walking into it. This
delivers the trap at the moment it applies: an edit under a topic's
`paths`, or a Bash command matching its `command`.

Reminders, never decisions:
  - **model-only**: `additionalContext`, no `systemMessage` -- it's context
    for the agent, and the human doesn't need a banner per edit. (The
    impermanence guard, a warning the human should see too, stays its own
    hook; its topic sets `delivered_by` and is skipped here.)
  - **once per topic per session**: shown topic ids go in a state file
    keyed by the payload's session id (`session_id`, or ZCode's
    `sessionId`), under $LESSON_REMINDER_STATE_DIR, else
    $XDG_RUNTIME_DIR, else the temp dir. No session id: no dedup.
  - **fail-open, visibly**: any error is one systemMessage and exit 0, never
    a blocked call. Two exceptions stay silent: a state-file error (it
    costs the dedup, not the reminder) and a python3 older than 3.11 (no
    tomllib; a banner on every call would be worse than no reminder --
    `check_wiki.py lessons` fails loudly there instead).
  - a topic counts as shown once it is emitted, even if another guard then
    denies the call.

The map is read from the nearest ancestor of the edited file (or of the
Bash call's cwd) holding .agents/lessons-map.toml, so a worktree is matched
against its own map. Matching lives in lessons_map.py beside this file,
shared with `just agent lessons` and `check_wiki.py lessons`.
"""
import hashlib
import json
import os
import pathlib
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))


def state_file(payload):
    sid = payload.get('session_id') or payload.get('sessionId')
    if not sid:
        return None
    base = (os.environ.get('LESSON_REMINDER_STATE_DIR')
            or os.environ.get('XDG_RUNTIME_DIR') or tempfile.gettempdir())
    digest = hashlib.sha256(str(sid).encode()).hexdigest()[:16]
    return pathlib.Path(base) / f'lesson-reminders-{digest}'


def unseen(topics, path):
    """Topics not yet shown this session; records the ones returned. State
    is best-effort: an unreadable or unwritable state file costs the dedup,
    never the reminder. Two hook processes racing can both remind once."""
    if path is None:
        return topics
    try:
        shown = set(path.read_text().split())
    except OSError:
        shown = set()
    fresh = [t for t in topics if t['id'] not in shown]
    if fresh:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, 'a') as f:
                f.write(''.join(t['id'] + '\n' for t in fresh))
        except OSError:
            pass
    return fresh


def topics_for(payload, lessons_map):
    tool = payload.get('tool_name') or payload.get('toolName') or ''
    tin = payload.get('tool_input') or payload.get('toolInput') or {}
    if tool == 'Bash':
        command = tin.get('command') or ''
        if not isinstance(command, str):
            return []
        cwd = payload.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or '.'
        root = lessons_map.find_root(pathlib.Path(cwd).resolve())
        if not command or root is None:
            return []
        return lessons_map.match_command(lessons_map.load(root), command)
    file_path = tin.get('file_path') or tin.get('filePath') or ''
    if not file_path or not isinstance(file_path, str):
        return []
    path = pathlib.Path(file_path)
    if not path.is_absolute():
        base = payload.get('cwd') or os.environ.get('CLAUDE_PROJECT_DIR') or '.'
        path = pathlib.Path(base) / path
    path = pathlib.Path(os.path.normpath(path))
    root = lessons_map.find_root(path.parent)
    if root is None:
        return []
    rel = path.relative_to(root).as_posix()
    creating = tool == 'Write' and not path.exists()
    out = []
    for t in lessons_map.match_path(lessons_map.load(root), rel):
        on = t.get('remind_on', 'edit')
        if t.get('delivered_by') or on == 'never':
            continue
        if on == 'create' and not creating:
            continue
        out.append(t)
    return out


def main():
    try:
        import lessons_map
        if lessons_map.tomllib is None:
            return 0  # Python < 3.11: no reminders, and no banner per call
        payload = json.load(sys.stdin)
        topics = [t for t in topics_for(payload, lessons_map) if t.get('remind')]
        topics = unseen(topics, state_file(payload))
    except Exception as e:  # noqa: BLE001 -- fail open, but say so
        print(json.dumps({'systemMessage':
              f'lesson-reminder: {type(e).__name__}: {e} -- no lesson '
              f'reminders for this call (.agents/hooks/lessons_map.py)'}))
        return 0
    if not topics:
        return 0
    lines = [f"LESSON REMINDER ({t['id']}): {t['remind']} "
             f"Full rule: {lessons_map.pointers(t)}." for t in topics]
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'additionalContext': '\n'.join(lines)}}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
