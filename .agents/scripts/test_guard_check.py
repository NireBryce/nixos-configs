#!/usr/bin/env python3
"""Fixtures for guard_check.py. Fake hook scripts pin down how each kind of
hook answer maps to an exit status; one integration case runs the real hooks
against a temp repo (skipped without jq, which the hooks need). Stdlib only.
"""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import guard_check  # noqa: E402


def reply(decision=None, reason="r", system=None):
    out = {}
    if decision or reason:
        out["hookSpecificOutput"] = {
            "hookEventName": "PreToolUse",
            **({"permissionDecision": decision} if decision else {}),
            **({"permissionDecisionReason": reason} if decision else
               {"additionalContext": reason})}
    if system:
        out["systemMessage"] = system
    return json.dumps(out)


class Mapping(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="guard-check-"))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)

    def hook(self, name, body):
        p = self.dir / name
        p.write_text("#!/usr/bin/env bash\ncat >/dev/null\n" + body)
        p.chmod(0o755)
        return f'"{p}"'

    def code(self, *hooks):
        results = guard_check.run_hooks("ls", self.dir, "s", hooks=list(hooks))
        return guard_check.exit_code(results), results

    def test_silent_hook_allows(self):
        self.assertEqual(self.code(self.hook("a.sh", "exit 0"))[0], 0)

    def test_deny_ask_error_codes(self):
        deny = self.hook("d.sh", f"echo '{reply('deny')}'")
        ask = self.hook("k.sh", f"echo '{reply('ask')}'")
        self.assertEqual(self.code(deny)[0], 2)
        self.assertEqual(self.code(ask)[0], 3)

    def test_worst_answer_wins(self):
        deny = self.hook("d.sh", f"echo '{reply('deny')}'")
        ask = self.hook("k.sh", f"echo '{reply('ask')}'")
        ok = self.hook("a.sh", "exit 0")
        self.assertEqual(self.code(ok, ask, deny)[0], 2)

    def test_exit_two_is_a_deny_with_stderr_as_reason(self):
        code, res = self.code(self.hook("x.sh", "echo nope >&2; exit 2"))
        self.assertEqual(code, 2)
        self.assertIn("nope", res[0][2])

    def test_reminder_is_a_note_not_an_objection(self):
        code, res = self.code(self.hook("n.sh", f"echo '{reply()}'"))
        self.assertEqual((code, res[0][1]), (0, "note"))

    def test_crash_and_bad_json_are_errors_not_passes(self):
        self.assertEqual(self.code(self.hook("c.sh", "exit 7"))[0], 4)
        self.assertEqual(self.code(self.hook("j.sh", "echo not-json"))[0], 4)

    def test_unchecked_warning_is_an_error_not_a_pass(self):
        msg = json.dumps({"systemMessage":
                          "x-guard: jq not on PATH, so this was NOT checked"})
        self.assertEqual(
            self.code(self.hook("u.sh", f"echo '{msg}'"))[0], 4)

    def test_missing_hook_is_an_error(self):
        self.assertEqual(self.code(f'"{self.dir}/absent.sh"')[0], 4)

    def test_payload_shape(self):
        out = self.dir / "seen.json"
        h = self.hook("p.sh", f"true")
        # Re-write to capture stdin instead of discarding it.
        Path(h.strip('"')).write_text(
            f"#!/usr/bin/env bash\ncat > {out}\n")
        guard_check.run_hooks("git status", self.dir, "sess", hooks=[h])
        got = json.loads(out.read_text())
        self.assertEqual(got["tool_name"], "Bash")
        self.assertEqual(got["tool_input"]["command"], "git status")
        self.assertEqual(got["hook_event_name"], "PreToolUse")


class Settings(unittest.TestCase):
    def test_reads_the_bash_matcher_hooks_from_settings(self):
        hooks = guard_check.bash_pretooluse_hooks()
        names = [Path(h.strip('"')).name for h in hooks]
        self.assertIn("git-guard-pretooluse.sh", names)
        self.assertNotIn("impermanence-edit-guard-pretooluse.sh", names)

    def test_other_matchers_are_skipped(self):
        d = Path(tempfile.mkdtemp(prefix="guard-check-"))
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        (d / "s.json").write_text(json.dumps({"hooks": {"PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "a"}]},
            {"matcher": "Read|Bash", "hooks": [{"type": "command", "command": "b"}]},
            {"matcher": "Edit", "hooks": [{"type": "command", "command": "c"}]},
        ]}}))
        self.assertEqual(guard_check.bash_pretooluse_hooks(d / "s.json"),
                         ["a", "b"])


@unittest.skipUnless(shutil.which("jq"), "the real hooks need jq")
class RealHooks(unittest.TestCase):
    def setUp(self):
        self.repo = Path(tempfile.mkdtemp(prefix="guard-check-repo-"))
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        def git(*a):
            subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=t",
                            "-c", "user.email=t@t", *a], check=True,
                           capture_output=True)
        git("init", "-q")
        (self.repo / "f").write_text("a\n")
        git("add", "f")
        git("commit", "-qm", "i")
        (self.repo / "f").write_text("b\n")   # dirty

    def run_cli(self, command):
        return subprocess.run(
            [sys.executable, str(Path(guard_check.__file__)),
             "--cwd", str(self.repo), "--", command],
            capture_output=True, text=True)

    def test_discarding_a_dirty_tree_is_denied(self):
        p = self.run_cli("git reset --hard")
        self.assertEqual(p.returncode, 2, p.stdout)
        self.assertIn("DENY", p.stdout)

    def test_a_harmless_command_passes(self):
        p = self.run_cli("ls")
        self.assertEqual(p.returncode, 0, p.stdout)


if __name__ == "__main__":
    unittest.main()
