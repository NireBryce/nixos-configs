#!/usr/bin/env python3
"""Fixture tests for the guard hooks -- the safety-critical pattern-matcher
class this repo already fixture-tests elsewhere (branches.py's classifier,
#303; the keybinding parsers, #371), and the only such scripts that had no
tests at all until 2026-09-29.

The incident record is the reason this file exists. Each Bash guard has
already gone subtly wrong once in production: secrets-guard-pretooluse's
/dev/null exemption matched a `2>/dev/null` and let three values out
(2026-09-09), and secrets-guard-posttooluse's jq `tostring` glued newlines
into literal `\\n` and flagged a plain list of key names as a leak
(2026-08-26). Both were found live, by luck, after shipping. A guard that
stops matching fails silently -- with the settings' `|| true`, a broken
hook is indistinguishable from no hook -- so every shape below is a
regression pin, not a spec: what must trip, what must pass, and the exact
verdict field the harness reads.

What runs: the four .agents/hooks/ guards with synthetic stdin JSON (the
untracked guard against a throwaway git repo with a planted untracked
.nix), .githooks/commit-msg against a temp message file, and `bash -n`
over every hook including .githooks/pre-commit (which is NOT driven
end-to-end -- it would run lint.py for real, and CI already runs that same
check as `just lint`). Also pins the wiring: every hook .sh on disk is
referenced by .agents/settings.json and executable, and every hook command
settings.json names exists on disk, so a guard can't silently fall out of
-- or never enter -- the harness config.

jq is required (the guards need it too); without it the test skips with a
note, the way .githooks/pre-commit skips without statix. Pure stdlib plus
bash, jq, git; no network, no fleet state. Runs via `just guards-test`,
part of `just preflight` and CI.
"""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

REPO = pathlib.Path(__file__).resolve().parents[2]
HOOKS = REPO / ".agents" / "hooks"
GIT_HOOKS = REPO / ".githooks"
SETTINGS = REPO / ".agents" / "settings.json"


def run_guard(script, payload):
    """Run a guard hook with synthetic stdin; return parsed stdout JSON or
    None. Fails the calling test if the script exits non-zero -- under the
    settings' `2>/dev/null || true` that failure would be silent in real
    use, so here it is always a finding."""
    proc = subprocess.run(
        ["bash", str(script)], input=json.dumps(payload).encode(),
        capture_output=True, timeout=60)
    if proc.returncode != 0:
        raise AssertionError(
            f"{script.name} exited {proc.returncode} -- a guard that errors "
            f"is a guard that no longer runs. stderr:\n"
            f"{proc.stderr.decode(errors='replace')}")
    out = proc.stdout.decode()
    return json.loads(out) if out.strip() else None


def bash_payload(command, cwd=None):
    return {"tool_name": "Bash", "tool_input": {"command": command},
            "cwd": str(cwd or REPO)}


class GuardCase(unittest.TestCase):
    def assertAsk(self, script, command, needle=None, cwd=None):
        out = run_guard(script, bash_payload(command, cwd))
        decision = (out or {}).get("hookSpecificOutput", {}).get(
            "permissionDecision")
        self.assertEqual(
            decision, "ask",
            f"{script.name} did not ask for confirmation on: {command!r}\n"
            f"stdout was: {out}")
        if needle:
            text = " ".join(filter(None, [
                (out or {}).get("systemMessage", ""),
                (out or {}).get("hookSpecificOutput", {}).get(
                    "permissionDecisionReason", "")]))
            self.assertIn(needle, text)
        return out

    def assertPass(self, script, command, cwd=None):
        out = run_guard(script, bash_payload(command, cwd))
        decision = (out or {}).get("hookSpecificOutput", {}).get(
            "permissionDecision")
        self.assertIsNone(
            decision,
            f"{script.name} flagged a command that should pass: "
            f"{command!r}\nstdout was: {out}")


class SecretsGuardPreToolUse(GuardCase):
    script = HOOKS / "secrets-guard-pretooluse.sh"

    def test_bare_decrypt_trips(self):
        self.assertAsk(self.script, "sops -d secrets.yaml", "2026-08-26")

    def test_stderr_redirect_still_trips(self):
        # The 2026-09-09 shape: 2>/dev/null redirects stderr only; stdout
        # (the whole decrypted file) still flows. This exact case is what
        # the original /dev/null exemption got wrong.
        self.assertAsk(self.script, "sops -d secrets.yaml 2>/dev/null")

    def test_pipe_still_trips(self):
        self.assertAsk(self.script,
                       "sops -d secrets.yaml | grep tailscale_key")

    def test_stdout_devnull_no_pipe_passes(self):
        # The documented exit-code-check idiom the guard's reason text
        # recommends -- must keep working or the guard is unusable.
        self.assertPass(self.script, "sops -d secrets.yaml >/dev/null 2>&1; echo $?")

    def test_fd1_devnull_passes(self):
        self.assertPass(self.script, "sops -d secrets.yaml 1>/dev/null 2>&1")

    def test_extract_exempts_even_piped(self):
        self.assertPass(self.script,
                        """sops -d --extract '["tailscale_key"]' secrets.yaml | grep -c .""")

    def test_reading_run_secrets_trips(self):
        self.assertAsk(self.script, "cat /run/secrets/atuin_key")

    def test_stat_run_secrets_passes(self):
        self.assertPass(self.script, "stat /run/secrets/atuin_key")

    def test_read_sops_names_passes(self):
        # The safe answer to "which secrets exist?" -- must never be gated.
        self.assertPass(self.script, "just read-sops-names")

    def test_unrelated_command_passes(self):
        self.assertPass(self.script, "nix eval --raw .#x --apply 'toString'")


class SecretsGuardPostToolUse(GuardCase):
    script = HOOKS / "secrets-guard-posttooluse.sh"

    def run_tool_output(self, tool_response):
        return run_guard(self.script, {"tool_name": "Bash",
                                       "tool_input": {"command": "x"},
                                       "tool_response": tool_response})

    def assertBlock(self, tool_response, needle):
        out = self.run_tool_output(tool_response)
        self.assertEqual((out or {}).get("decision"), "block",
                         f"no block for output containing {needle}:\n{out}")
        self.assertIn(needle, (out or {}).get("reason", ""))

    def test_tskey_flagged(self):
        # Fixture strings match the guard's shape regexes but are kept
        # short and low-entropy on purpose: GitGuardian's PR scan flagged
        # a longer fake tskey as a real secret (2026-09-29), turning the
        # PR red for a string invented to be fake.
        self.assertBlock("authed: tskey-EXAMPLE\n", "Tailscale")

    def test_age_key_flagged(self):
        self.assertBlock("AGE-SECRET-KEY-1ABCDEF023456789\n", "age")

    def test_private_key_block_flagged(self):
        self.assertBlock("-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n",
                         "private key")

    def test_encrypted_blob_not_flagged(self):
        # ENC[...] is ciphertext, safe to show -- CLAUDE.md's Safety section.
        out = self.run_tool_output(
            "tailscale_key: ENC[AES256_GCM,data:abc123,iv:xyz,tag:def,type:str]\n")
        self.assertIsNone((out or {}).get("decision"))

    def test_key_name_list_not_flagged(self):
        # Pins the 2026-08-26 jq-tostring bug: an object tool_response with
        # real newlines must be read as text, and a bare list of key NAMES
        # with no values is not a leak.
        out = self.run_tool_output({"stdout": "tailscale_key\natuin_key\n",
                                    "stderr": ""})
        self.assertIsNone((out or {}).get("decision"))


class GitGuardPreToolUse(GuardCase):
    script = HOOKS / "git-guard-pretooluse.sh"

    def test_force_push_trips(self):
        self.assertAsk(self.script, "git push -f origin main")

    def test_force_long_form_trips(self):
        self.assertAsk(self.script, "git push --force origin experimental")

    def test_force_with_lease_passes(self):
        self.assertPass(self.script, "git push --force-with-lease origin main")

    def test_push_delete_trips(self):
        self.assertAsk(self.script, "git push origin --delete some-branch")

    def test_push_colon_refspec_trips(self):
        self.assertAsk(self.script, "git push origin :some-branch")

    def test_push_mirror_trips(self):
        self.assertAsk(self.script, "git push --mirror origin")

    def test_reset_hard_trips(self):
        # The ship skill's documented recovery step -- expected to ask, not
        # wrong to run (the hook header says so).
        self.assertAsk(self.script, "git reset --hard origin/experimental")

    def test_clean_force_trips(self):
        self.assertAsk(self.script, "git clean -fd")

    def test_checkout_dot_trips(self):
        self.assertAsk(self.script, "git checkout .")
        self.assertAsk(self.script, "git checkout -- .")

    def test_branch_capital_d_trips(self):
        self.assertAsk(self.script, "git branch -D stale-branch")

    def test_branch_lowercase_d_passes(self):
        # The ship skill's routine post-merge cleanup.
        self.assertPass(self.script, "git branch -d merged-branch")

    def test_stash_drop_trips(self):
        self.assertAsk(self.script, "git stash drop stash@{0}")

    def test_restore_dot_trips(self):
        # The modern spelling of `checkout -- .` -- added 2026-09-29; the
        # original hook covered only the checkout spelling.
        self.assertAsk(self.script, "git restore .")

    def test_restore_worktree_flag_trips(self):
        self.assertAsk(self.script, "git restore --worktree .")
        self.assertAsk(self.script, "git restore -w some-file.txt")

    def test_restore_staged_dot_asks(self):
        # `--staged .` only unstages, but it trips anyway. The original
        # carve-out negated a whole-command `--staged` grep, which leaked
        # across `&&`: `git restore --staged file1 && git restore .` and
        # `git restore . && echo --staged` both suppressed the ask (found
        # in review, 2026-09-29). Telling the safe dot form apart needs
        # segment-scoped parsing the hook deliberately doesn't do, and
        # over-asking is the safe direction for an ask.
        self.assertAsk(self.script, "git restore --staged .")

    def test_restore_staged_single_file_passes(self):
        # No dot target: content-preserving and narrow, same granularity
        # as `checkout -- <file>`.
        self.assertPass(self.script, "git restore --staged some-file.txt")

    def test_restore_combined_line_asks(self):
        # A `--staged` earlier in the line must not suppress a destructive
        # restore later in it. The dot-target regex is segment-scoped
        # ([^;|&]*), so the second restore's bare dot is still visible.
        self.assertAsk(self.script,
                       "git restore --staged file1 && git restore .")
        self.assertAsk(self.script, "git restore . && echo --staged")

    def test_restore_single_file_passes(self):
        # Same granularity as checkout: single-file restores pass, exactly
        # like `git checkout -- <file>` does; a bare-dot target or an
        # explicit --worktree/-w flag is what asks.
        self.assertPass(self.script, "git restore some-file.txt")

    def test_worktree_remove_force_trips(self):
        self.assertAsk(self.script, "git worktree remove --force /tmp/wt-x")

    def test_worktree_remove_plain_passes(self):
        self.assertPass(self.script, "git worktree remove /tmp/wt-x")

    def test_path_containing_guard_words_passes(self):
        # `restore` and `remove` are anchored to a following space/EOL so
        # they are read as verbs, never as path fragments.
        self.assertPass(self.script,
                        "git add flake/modules/general-config/impermanence/"
                        "root-rollback/restore-root/WARN-impermanence.nix && "
                        "git commit -m x")

    def test_ask_travels_with_systemMessage(self):
        # The #182 rationale in the hook's own header: permissionDecision
        # "ask" is a silent no-op under an auto permission mode, while
        # systemMessage always reaches the transcript. Pin that both
        # travel together on a destructive-git ask.
        out = self.assertAsk(self.script, "git push -f origin main")
        self.assertIn("DESTRUCTIVE GIT COMMAND",
                      (out or {}).get("systemMessage", ""))

    def test_benign_commands_pass(self):
        for cmd in ("git status -sb", "git add -A", "git log --oneline -5",
                    "just build"):
            self.assertPass(self.script, cmd)


class ImpermanenceEditGuard(unittest.TestCase):
    script = HOOKS / "impermanence-edit-guard-pretooluse.sh"

    # Pins the tree, not just the pattern: the warn tests below feed path
    # strings, which would all stay green through a rename of the guarded
    # directories while the guard silently protected nothing. A rename
    # must fail here and be carried into the hook's case patterns and
    # these constants in the same change.
    GUARDED = (
        "flake/modules/general-config/impermanence/root-rollback/"
        "restore-root/WARN-impermanence.nix",
        "flake/modules/host-config/tenacity/hardware/hardware-tenacity.nix",
    )

    def test_guarded_paths_exist(self):
        for rel in self.GUARDED:
            self.assertTrue((REPO / rel).exists(), rel)

    def run_edit(self, file_path):
        return run_guard(self.script, {"tool_name": "Edit",
                                       "tool_input": {"file_path": file_path}})

    def test_impermanence_tree_warns(self):
        out = self.run_edit(str(REPO / self.GUARDED[0]))
        self.assertIn("PROTECTED-CONFIG EDIT", (out or {}).get("systemMessage", ""))

    def test_host_hardware_module_warns(self):
        out = self.run_edit(str(REPO / self.GUARDED[1]))
        self.assertIn("PROTECTED-CONFIG EDIT", (out or {}).get("systemMessage", ""))

    def test_relative_path_warns(self):
        # The harness contract is absolute paths; the hook's bare-form
        # arms cover a relative one anyway, over-warning on an
        # identically-shaped tree copied elsewhere (right direction).
        out = self.run_edit(self.GUARDED[0])
        self.assertIn("PROTECTED-CONFIG EDIT", (out or {}).get("systemMessage", ""))

    def test_lookalike_paths_pass(self):
        # `*` must anchor on the real directory components, not a
        # substring: a file merely named after the tree is not the tree.
        for p in (str(REPO / "flake/modules/general-config/impermanence-notes.md"),
                  "/tmp/impermanence-scratch/foo.nix"):
            self.assertIsNone(self.run_edit(p))

    def test_ordinary_module_passes(self):
        out = self.run_edit(str(REPO / "flake/modules/general-config/system"
                                       "/foo.nix"))
        self.assertIsNone(out)

    def test_missing_path_passes(self):
        self.assertIsNone(self.run_edit(""))


class NixUntrackedGuard(GuardCase):
    script = HOOKS / "nix-untracked-guard-pretooluse.sh"

    def setUp(self):
        self.repo = pathlib.Path(tempfile.mkdtemp(prefix="untracked-guard-"))
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        git = lambda *a: subprocess.run(
            ["git", "-C", str(self.repo), *a], check=True, capture_output=True)
        git("-c", "init.defaultBranch=main", "init", "-q")
        (self.repo / "tracked.nix").write_text("{ }\n")
        git("add", "tracked.nix")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit",
            "-q", "-m", "init")

    def guard(self, command):
        return run_guard(self.script, bash_payload(command, cwd=self.repo))

    def test_untracked_nix_warns(self):
        (self.repo / "new-module.nix").write_text("{ }\n")
        out = self.guard("nix eval --raw .#x")
        self.assertIn("UNTRACKED", (out or {}).get("systemMessage", ""))
        self.assertIn("new-module.nix", (out or {}).get("systemMessage", ""))

    def test_git_command_does_not_warn(self):
        (self.repo / "new-module.nix").write_text("{ }\n")
        self.assertPass(self.script, "git status -sb", cwd=self.repo)

    def test_added_file_does_not_warn(self):
        (self.repo / "new-module.nix").write_text("{ }\n")
        subprocess.run(["git", "-C", str(self.repo), "add", "new-module.nix"],
                       check=True, capture_output=True)
        self.assertPass(self.script, "nix flake check --no-build",
                        cwd=self.repo)

    def test_just_recipes_are_watched(self):
        (self.repo / "new-module.nix").write_text("{ }\n")
        out = self.guard("just build")
        self.assertIn("UNTRACKED", (out or {}).get("systemMessage", ""))

    def test_nix_develop_warns(self):
        # develop evaluates this flake's devShells -- lower stakes than a
        # system eval, same invisibility for untracked modules.
        (self.repo / "new-module.nix").write_text("{ }\n")
        out = self.guard("nix develop")
        self.assertIn("UNTRACKED", (out or {}).get("systemMessage", ""))

    def test_non_evaluating_nix_commands_pass(self):
        (self.repo / "new-module.nix").write_text("{ }\n")
        for cmd in ("nix fmt", "nix shell nixpkgs#statix nixpkgs#deadnix",
                    "just modules", "git status"):
            self.assertPass(self.script, cmd, cwd=self.repo)

    def test_cwd_absent_falls_back_to_project_dir(self):
        # When the harness payload carries no .cwd, the guard falls back
        # to CLAUDE_PROJECT_DIR -- pin that the fallback actually lands in
        # a repo with untracked files and warns there.
        (self.repo / "new-module.nix").write_text("{ }\n")
        payload = {"tool_name": "Bash",
                   "tool_input": {"command": "nix eval --raw .#x"}}
        with mock.patch.dict(os.environ,
                             {"CLAUDE_PROJECT_DIR": str(self.repo)}):
            out = run_guard(self.script, payload)
        self.assertIn("UNTRACKED", (out or {}).get("systemMessage", ""))


class CommitMsgHook(unittest.TestCase):
    script = GIT_HOOKS / "commit-msg"

    def run_hook(self, message):
        fd, path = tempfile.mkstemp(suffix=".msg")
        os.close(fd)
        pathlib.Path(path).write_text(message)
        try:
            subprocess.run(["bash", str(self.script), path], check=True,
                           capture_output=True, timeout=30)
            return pathlib.Path(path).read_text()
        finally:
            os.unlink(path)

    def test_model_name_trailer_is_corrected(self):
        # 82 wrong "Sonnet 5" and 54 wrong "Opus 5" trailers in the log --
        # an agent cannot verify which model executes it, so the hook fixes
        # the shape instead of trusting the writer.
        out = self.run_hook("subject\n\nCo-Authored-By: Claude Sonnet 5 "
                            "<claude@anthropic.com>\n")
        self.assertIn("Co-Authored-By: Claude\n", out)
        self.assertNotIn("Sonnet", out)
        self.assertNotIn("anthropic.com", out)

    def test_canonical_trailer_untouched(self):
        msg = "subject\n\nCo-Authored-By: Claude\n"
        self.assertEqual(self.run_hook(msg), msg)

    def test_non_claude_trailer_passes_through(self):
        msg = "subject\n\nCo-Authored-By: ZCode\n"
        self.assertEqual(self.run_hook(msg), msg)

    def test_body_untouched(self):
        msg = "subject\n\nBody text.\n"
        self.assertEqual(self.run_hook(msg), msg)


class Wiring(unittest.TestCase):
    """A guard on disk but not in settings.json protects nothing; a
    settings.json entry with no script behind it breaks silently via the
    `|| true`. Keep the two lists equal, and every hook executable."""

    def test_settings_reference_existing_executable_hooks(self):
        config = json.loads(SETTINGS.read_text())
        referenced = []
        for group in config["hooks"].values():
            for entry in group:
                for hook in entry["hooks"]:
                    referenced += re.findall(r"\.agents/hooks/[\w-]+\.sh",
                                             hook["command"])
        self.assertTrue(referenced, "settings.json wires no hooks at all")
        for rel in referenced:
            path = REPO / rel
            self.assertTrue(path.exists(), f"{rel} referenced but missing")
            self.assertTrue(os.access(path, os.X_OK), f"{rel} not executable")

    def test_every_hook_script_is_wired(self):
        config = json.loads(SETTINGS.read_text())
        referenced = set()
        for group in config["hooks"].values():
            for entry in group:
                for hook in entry["hooks"]:
                    referenced |= set(re.findall(r"\.agents/hooks/[\w-]+\.sh",
                                                 hook["command"]))
        on_disk = {f".agents/hooks/{p.name}"
                   for p in HOOKS.glob("*.sh")}
        self.assertEqual(on_disk, referenced,
                         "a guard exists on disk but is not wired into "
                         "settings.json (or vice versa)")

    def test_every_hook_parses(self):
        for script in [*HOOKS.glob("*.sh"), *GIT_HOOKS.glob("*")]:
            with self.subTest(script=script.name):
                subprocess.run(["bash", "-n", str(script)], check=True,
                               capture_output=True)


if __name__ == "__main__":
    if shutil.which("jq") is None:
        print("test_guards: jq not on PATH -- skipping (the guards need it "
              "too; `nix shell nixpkgs#jq`, or run on a host with "
              "packages-config/nix-utils/ installed)")
        sys.exit(0)
    unittest.main()
