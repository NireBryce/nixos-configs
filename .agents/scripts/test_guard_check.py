#!/usr/bin/env python3
"""Fixtures for guard_check.py. Fake hook scripts pin down how each kind of
hook answer maps to an exit status; one integration case runs the real hooks
against a temp repo (skipped without jq, which the hooks need). Stdlib only.
"""
import json
import os
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
        results = guard_check.run_hooks("ls", self.dir, "s", hooks=list(hooks),
                                        hook_root=self.dir)
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
        guard_check.run_hooks("git status", self.dir, "sess", hooks=[h],
                              hook_root=self.dir)
        got = json.loads(out.read_text())
        self.assertEqual(got["tool_name"], "Bash")
        self.assertEqual(got["tool_input"]["command"], "git status")
        self.assertEqual(got["hook_event_name"], "PreToolUse")


class Untrusted(unittest.TestCase):
    """settings.json is repo content and this script may run in a checkout
    nobody vetted: a hook entry is a bare script under the hooks directory,
    or it is refused and never executed."""

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="guard-check-"))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        self.root = self.dir / "hooks"
        self.root.mkdir()
        self.marker = self.dir / "ran"

    def attempt(self, hook):
        res = guard_check.run_hooks("ls", self.dir, "s", hooks=[hook],
                                    hook_root=self.root)
        return guard_check.exit_code(res), res

    def assertRefused(self, hook):
        code, res = self.attempt(hook)
        self.assertEqual(code, 4)
        self.assertIn("refused to run", res[0][2])
        self.assertFalse(self.marker.exists(), "the command ran")

    def test_shell_pipeline_is_refused_not_run(self):
        self.assertRefused(f"touch {self.marker}; true")

    def test_arguments_are_refused(self):
        script = self.root / "h.sh"
        script.write_text("#!/usr/bin/env bash\ntouch %s\n" % self.marker)
        script.chmod(0o755)
        self.assertRefused(f"{script} extra")

    def test_command_substitution_is_refused(self):
        self.assertRefused(f"$(touch {self.marker})")

    def test_script_outside_the_hooks_dir_is_refused(self):
        out = self.dir / "outside.sh"
        out.write_text("#!/usr/bin/env bash\ntouch %s\n" % self.marker)
        out.chmod(0o755)
        self.assertRefused(str(out))

    def test_symlink_out_of_the_hooks_dir_is_refused(self):
        out = self.dir / "outside.sh"
        out.write_text("#!/usr/bin/env bash\ntouch %s\n" % self.marker)
        out.chmod(0o755)
        (self.root / "link.sh").symlink_to(out)
        self.assertRefused(str(self.root / "link.sh"))

    def test_non_executable_file_is_refused(self):
        (self.root / "n.sh").write_text("touch %s\n" % self.marker)
        self.assertRefused(str(self.root / "n.sh"))

    def test_a_bare_script_under_the_dir_runs(self):
        script = self.root / "ok.sh"
        script.write_text("#!/usr/bin/env bash\ncat >/dev/null\n")
        script.chmod(0o755)
        self.assertEqual(self.attempt(f'"{script}"')[0], 0)

    def test_every_hook_in_the_real_settings_resolves(self):
        for hook in guard_check.bash_pretooluse_hooks():
            guard_check.resolve_hook(hook)

    def test_terminal_escapes_are_not_printed(self):
        out = guard_check.clean("a\x1b[2Jb\x07c\nd")
        self.assertNotIn("\x1b", out)
        self.assertNotIn("\x07", out)
        self.assertIn("\n", out)

    def test_long_output_is_truncated(self):
        self.assertTrue(guard_check.clean("x" * 5000).endswith("[truncated]"))


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
            # Isolated from the user's global config: the session's
            # commit.gpgsign + agent-served signing key must not decide
            # whether a fixture commit can happen at all.
            env = dict(os.environ,
                       GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_CONFIG_SYSTEM=os.devnull)
            subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=t",
                            "-c", "user.email=t@t", *a], check=True,
                           capture_output=True, env=env)
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
