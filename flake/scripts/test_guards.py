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
stops matching fails silently -- until 2026-09-29 the settings wrapped
every hook in `2>/dev/null || true`, so a broken hook was indistinguishable
from no hook -- so every shape below is a regression pin, not a spec: what
must trip, what must pass, and the exact verdict field the harness reads.

What runs: every .agents/hooks/ script with synthetic stdin JSON (the
untracked guard, git-guard's dirty-tree check, the SessionStart hook and the
edit-check hook against throwaway git repos), each hook again with jq off
PATH (it must warn, not silently allow), .githooks/commit-msg against a temp message file, and `bash -n`
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


def run_hook_raw(script, payload, env=None, cwd=None):
    """Run a hook; return (returncode, stdout text)."""
    proc = subprocess.run(
        ["bash", str(script)], input=json.dumps(payload).encode(),
        capture_output=True, timeout=60, env=env, cwd=cwd)
    return proc.returncode, proc.stdout.decode()


def make_repo(prefix="guard-repo-"):
    """A throwaway git repo with one commit; caller removes it."""
    repo = pathlib.Path(tempfile.mkdtemp(prefix=prefix))
    git(repo, "-c", "init.defaultBranch=main", "init", "-q")
    (repo / "tracked.txt").write_text("a\n")
    git(repo, "add", "tracked.txt")
    git(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit",
        "-q", "-m", "init")
    return repo


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True,
                          capture_output=True, text=True).stdout


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

    def assertDeny(self, script, command, needle=None, cwd=None):
        out = run_guard(script, bash_payload(command, cwd))
        hso = (out or {}).get("hookSpecificOutput", {})
        self.assertEqual(
            hso.get("permissionDecision"), "deny",
            f"{script.name} did not deny: {command!r}\nstdout was: {out}")
        # A deny travels with a systemMessage so the human sees it too.
        self.assertTrue((out or {}).get("systemMessage"))
        if needle:
            self.assertIn(needle, hso.get("permissionDecisionReason", ""))
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
        self.assertDeny(self.script, "sops -d secrets.yaml", "2026-08-26")

    def test_stderr_redirect_still_trips(self):
        # The 2026-09-09 shape: 2>/dev/null redirects stderr only; stdout
        # (the whole decrypted file) still flows. This exact case is what
        # the original /dev/null exemption got wrong.
        self.assertDeny(self.script, "sops -d secrets.yaml 2>/dev/null")

    def test_pipe_still_trips(self):
        self.assertDeny(self.script,
                        "sops -d secrets.yaml | grep tailscale_key")
        # The exact 2026-09-09 line shape: stderr silenced, stdout piped.
        self.assertDeny(self.script, "sops -d f 2>/dev/null | grep x")

    def test_deny_reason_names_the_safe_forms(self):
        # A deny is only usable if the model can retry with the safe form,
        # so the reason must name all three.
        out = self.assertDeny(self.script, "sops -d secrets.yaml")
        reason = out["hookSpecificOutput"]["permissionDecisionReason"]
        for form in ("--extract", ">/dev/null 2>&1", "just read-sops-names"):
            self.assertIn(form, reason)

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
        self.assertDeny(self.script, "cat /run/secrets/atuin_key")

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

    # Tier 1: reset --hard / checkout . / clean -f / forced checkout+switch
    # decide on `git status --porcelain` in the target repo, not the string.

    STATE_CHECKED = ("git reset --hard", "git reset --hard HEAD",
                     "git checkout .", "git checkout -- .",
                     "git checkout -f main", "git switch --discard-changes main",
                     "git clean -fd")

    def repo(self):
        r = make_repo("git-guard-")
        self.addCleanup(shutil.rmtree, r, ignore_errors=True)
        return r

    def test_clean_tree_allows_silently(self):
        # The ship skill's `reset --hard origin/experimental` recovery after
        # `git branch <b>` has nothing to lose on a clean tree.
        r = self.repo()
        for cmd in self.STATE_CHECKED:
            self.assertIsNone(run_guard(self.script, bash_payload(cmd, r)),
                              cmd)

    def test_dirty_tracked_denies_with_paths(self):
        # The #182 shape: someone else's uncommitted edit in the tree.
        r = self.repo()
        (r / "tracked.txt").write_text("changed\n")
        for cmd in self.STATE_CHECKED[:-1]:
            out = self.assertDeny(self.script, cmd, "tracked.txt", cwd=r)
            self.assertIn("Ask the user",
                          out["hookSpecificOutput"]["permissionDecisionReason"])

    def test_untracked_only(self):
        # reset --hard leaves untracked files alone (-uno); clean deletes
        # exactly them.
        r = self.repo()
        (r / "scratch.txt").write_text("x\n")
        self.assertIsNone(run_guard(self.script,
                                    bash_payload("git reset --hard", r)))
        self.assertDeny(self.script, "git clean -fd", "scratch.txt", cwd=r)

    def test_clean_ignores_tracked_changes(self):
        r = self.repo()
        (r / "tracked.txt").write_text("changed\n")
        self.assertIsNone(run_guard(self.script,
                                    bash_payload("git clean -f", r)))

    def test_clean_x_counts_ignored(self):
        r = self.repo()
        (r / ".gitignore").write_text("result\n")
        git(r, "add", ".gitignore")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit",
            "-q", "-m", "ignore")
        (r / "result").write_text("x\n")
        self.assertIsNone(run_guard(self.script,
                                    bash_payload("git clean -fd", r)))
        self.assertDeny(self.script, "git clean -fdx", "result", cwd=r)

    def test_git_C_and_cd_pick_the_repo(self):
        # The payload cwd is clean; the command targets the dirty repo.
        clean, dirty = self.repo(), self.repo()
        (dirty / "tracked.txt").write_text("changed\n")
        self.assertDeny(self.script, f"git -C {dirty} reset --hard", cwd=clean)
        self.assertDeny(self.script, f"cd {dirty} && git reset --hard",
                        cwd=clean)
        self.assertIsNone(run_guard(self.script, bash_payload(
            f"git -C {clean} reset --hard", dirty)))

    def test_unresolvable_dir_asks(self):
        # `cd "$W"` can't be resolved without running the shell: unknown is
        # not clean, so it falls back to the ask.
        self.assertAsk(self.script, 'cd "$W" && git reset --hard',
                       "git status --short", cwd=self.repo())

    def test_not_a_repo_asks(self):
        d = pathlib.Path(tempfile.mkdtemp(prefix="git-guard-norepo-"))
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        self.assertAsk(self.script, "git reset --hard", cwd=d)

    def test_deny_outranks_ask(self):
        r = self.repo()
        (r / "tracked.txt").write_text("changed\n")
        self.assertDeny(self.script,
                        "git reset --hard && git push -f origin x", cwd=r)

    def test_clean_tree_still_asks_for_other_patterns(self):
        # Allowing the reset must not swallow a force push later in the line.
        self.assertAsk(self.script,
                       "git reset --hard && git push -f origin x",
                       cwd=self.repo())

    def test_inherited_git_dir_ignored(self):
        # lessons-learned §44: an inherited GIT_DIR retargets git. The hook
        # clears it, so the status is the target repo's, not GIT_DIR's.
        clean, dirty = self.repo(), self.repo()
        (dirty / "tracked.txt").write_text("changed\n")
        env = {**os.environ, "GIT_DIR": str(clean / ".git")}
        rc, out = run_hook_raw(self.script,
                               bash_payload("git reset --hard", dirty), env)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["hookSpecificOutput"]
                         ["permissionDecision"], "deny")

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

    def test_harness_default_trailer_is_corrected(self):
        # Claude Code's default when attribution.commit is unset: lowercase
        # key, email. settings.json sets it now; this is the backstop.
        out = self.run_hook("subject\n\nCo-authored-by: Claude "
                            "<claude@anthropic.com>\n")
        self.assertIn("Co-Authored-By: Claude\n", out)
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


def path_without_jq():
    """A PATH holding symlinks to every tool the hooks use except jq --
    jq usually shares a directory with the rest (/run/current-system/sw/
    bin), so dropping a whole directory from PATH can't isolate it."""
    d = pathlib.Path(tempfile.mkdtemp(prefix="nojq-"))
    for tool in ("bash", "cat", "git", "grep", "sed", "awk", "head", "wc",
                 "env", "dirname", "hostname", "uname", "python3"):
        found = shutil.which(tool)
        if found:
            (d / tool).symlink_to(found)
    return d


class MissingJq(unittest.TestCase):
    """No jq means no hook can read its input. Each must say so in a
    systemMessage (built by hand) and exit 0 -- never allow silently,
    which is what the old `|| true` wiring made of a missing jq."""

    def test_every_hook_warns_without_jq(self):
        d = path_without_jq()
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        # Run from a scratch repo, never this one: without jq the
        # SessionStart hook can't read .cwd and falls back to
        # CLAUDE_PROJECT_DIR/$PWD -- and it sets core.hooksPath there.
        scratch = make_repo("nojq-cwd-")
        self.addCleanup(shutil.rmtree, scratch, ignore_errors=True)
        env = {**os.environ, "PATH": str(d),
               "CLAUDE_PROJECT_DIR": str(scratch)}
        payload = {"tool_name": "Bash", "cwd": str(scratch),
                   "tool_input": {"command": "sops -d secrets.yaml",
                                  "file_path": str(REPO / "README.md")},
                   "tool_response": {"stdout": "", "stderr": ""}}
        for script in sorted(HOOKS.glob("*.sh")):
            with self.subTest(script=script.name):
                rc, out = run_hook_raw(script, payload, env, cwd=scratch)
                self.assertEqual(rc, 0)
                if script.name == "session-start.sh":
                    # SessionStart adds plain stdout to context.
                    self.assertIn("jq not on PATH", out)
                else:
                    self.assertIn("jq not on PATH",
                                  json.loads(out)["systemMessage"])


class SessionStart(unittest.TestCase):
    script = HOOKS / "session-start.sh"

    def context(self, cwd):
        out = run_guard(self.script, {"hook_event_name": "SessionStart",
                                      "source": "startup", "cwd": str(cwd)})
        hso = out["hookSpecificOutput"]
        self.assertEqual(hso["hookEventName"], "SessionStart")
        return hso["additionalContext"]

    def setUp(self):
        self.repo = make_repo("session-start-")
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        (self.repo / ".githooks").mkdir()

    def test_reports_state_and_sets_hooks_path(self):
        (self.repo / "tracked.txt").write_text("changed\n")
        ctx = self.context(self.repo)
        for needle in ("hostname:", "branch: main", "main checkout",
                       "dirty paths (git status --porcelain): 1",
                       "git worktree list:", "set it to .githooks"):
            self.assertIn(needle, ctx)
        self.assertEqual(git(self.repo, "config", "core.hooksPath").strip(),
                         ".githooks")
        # Idempotent: the second run reports, doesn't re-set.
        self.assertIn("core.hooksPath: .githooks (", self.context(self.repo))

    def test_linked_worktree_detected(self):
        wt = pathlib.Path(tempfile.mkdtemp(prefix="session-start-wt-")) / "wt"
        self.addCleanup(shutil.rmtree, wt.parent, ignore_errors=True)
        git(self.repo, "worktree", "add", "-q", str(wt), "-b", "side")
        ctx = self.context(wt)
        self.assertIn("branch: side", ctx)
        self.assertIn("LINKED worktree", ctx)

    def test_outside_a_repo_still_succeeds(self):
        d = pathlib.Path(tempfile.mkdtemp(prefix="session-start-norepo-"))
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        self.assertIn("not inside a git repo", self.context(d))


class EditCheck(unittest.TestCase):
    script = HOOKS / "edit-check-posttooluse.sh"

    def setUp(self):
        self.repo = make_repo("edit-check-")
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)

    def edit(self, rel):
        out = run_guard(self.script, {
            "tool_name": "Write", "cwd": str(self.repo),
            "tool_input": {"file_path": str(self.repo / rel)}})
        if out is None:
            return ""
        self.assertNotIn("decision", out)  # context only, never a block
        return out["hookSpecificOutput"]["additionalContext"]

    def write(self, rel, text):
        path = self.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def test_untracked_module_with_shell_interp(self):
        self.write("flake/modules/new.nix",
                   "{ x = ''\n  bindkey \"${terminfo[khome]}\" y\n''; }\n")
        ctx = self.edit("flake/modules/new.nix")
        self.assertIn("${terminfo[khome]}", ctx)
        self.assertIn("git add flake/modules/new.nix", ctx)

    def test_tracked_clean_module_is_silent(self):
        self.write("flake/modules/ok.nix",
                   "{ pkgs, ... }: { x = ''\n  ${pkgs.hello}/bin ''${HOME}\n''; }\n")
        git(self.repo, "add", "flake/modules/ok.nix")
        self.assertEqual(self.edit("flake/modules/ok.nix"), "")

    def test_wiki_stale_sibling(self):
        (self.repo / "wiki/scripts").mkdir(parents=True)
        shutil.copy(REPO / "wiki/scripts/check_wiki.py",
                    self.repo / "wiki/scripts/check_wiki.py")
        self.write("wiki/page.md", "# P\n\n_Last modified: 2026-09-29_\n\n"
                   "See [page-for-agents.md](page-for-agents.md).\n")
        self.write("wiki/page-for-agents.md",
                   "# P\n\n_Last modified: 2026-09-01_\n\n"
                   "Condensed from [page.md](page.md).\n")
        ctx = self.edit("wiki/page.md")
        self.assertIn("STALE SIBLING  wiki/page-for-agents.md", ctx)
        self.write("wiki/page-for-agents.md",
                   "# P\n\n_Last modified: 2026-09-29_\n\n"
                   "Condensed from [page.md](page.md).\n")
        self.assertEqual(self.edit("wiki/page.md"), "")

    def test_other_files_are_silent(self):
        self.write("README.md", "x\n")
        self.assertEqual(self.edit("README.md"), "")


class NixShellInterp(unittest.TestCase):
    """The lexer behind edit-check's `''`-string check. Its value is zero
    false positives: a hook that cries wolf on `${pkgs.foo}` gets ignored."""

    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(HOOKS))
        try:
            import nix_shell_interp
        finally:
            sys.path.remove(str(HOOKS))
        cls.mod = nix_shell_interp

    def find(self, text):
        return [snippet for _, snippet in self.mod.findings(text)]

    def test_shell_shapes_flagged(self):
        text = "''\n ${terminfo[khome]} ${VAR:-d} ${#arr} ${1} ${x%.nix}\n''"
        self.assertEqual(self.find(text), ["${terminfo[khome]}", "${VAR:-d}",
                                           "${#arr}", "${1}", "${x%.nix}"])

    def test_escapes_and_real_interpolation_pass(self):
        text = ("''\n ''${x:-y} $${a[1]} " + "'" * 3 + " ''\\n "
                "${pkgs.hello}/bin ${lib.concatMapStrings (x: \"${x}\") [ ]} "
                "${HOME}\n''")
        self.assertEqual(self.find(text), [])

    def test_only_indented_strings(self):
        # "..." strings and comments are out of scope.
        self.assertEqual(self.find("{ a = \"${x:-y}\"; # '' ${x[1]}\n}"), [])

    def test_recovers_after_a_hit(self):
        # `${#arr}` read as Nix would open a comment and swallow the rest.
        text = "{ a = ''\n ${#arr} ''${ok:-x}\n''; b = \"${y:-z}\"; }"
        self.assertEqual(self.find(text), ["${#arr}"])

    def test_whole_repo_is_clean(self):
        # Every tracked .nix evaluates, so any hit here is a false positive.
        files = subprocess.run(["git", "-C", str(REPO), "ls-files", "*.nix"],
                               capture_output=True, text=True).stdout.split()
        self.assertTrue(files)
        hits = [(f, s) for f in files for s in self.mod.findings(
            (REPO / f).read_text(errors="replace"))]
        self.assertEqual(hits, [])


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

    def test_no_fail_open_wrappers(self):
        # `2>/dev/null || true` hid every hook failure until 2026-09-29.
        # Exit code and JSON are the decision channel; a crash should show
        # up as a hook error, not vanish.
        config = json.loads(SETTINGS.read_text())
        for group in config["hooks"].values():
            for entry in group:
                for hook in entry["hooks"]:
                    self.assertNotIn("|| true", hook["command"])
                    self.assertNotIn("2>/dev/null", hook["command"])

    def test_attribution_is_canonical(self):
        # The harness-side trailer setting; .githooks/commit-msg is the
        # backstop for other harnesses and a stale settings file.
        config = json.loads(SETTINGS.read_text())
        self.assertEqual(config.get("attribution", {}).get("commit"),
                         "Co-Authored-By: Claude")

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
