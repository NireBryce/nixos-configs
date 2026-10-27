#!/usr/bin/env python3
"""Fixture tests for comment_wrap.py, the comment-width checker/fixer.

One half is the lexer: which lines are pure `#` comments, against the
shapes the tree actually holds and the ones wiki/config-structure/module-style-guide.md
warns about -- `#` shell comments inside `''` strings (fourteen lines of
maintenance notes once shipped into `~/.zshrc` that way), `${ ... }`
interpolations with strings and comments inside, and the `''` escape
forms. The other half is classification and the fix: a paragraph the
tool must catch and reflow (the lesson §1 case -- a checker tested
against what it exists to catch), the moving limit (80 + indent), the
exempt shapes it must never report or touch (URLs, aligned `# ... # ...`
tables, banners), and the hand-work classes it must report but leave
(`# summary:`, bullets, broken backtick spans, overflow tokens). Pure
stdlib; runs via `just comment-wrap-test`, part of `just preflight`.
"""
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, SCRIPTS)
import comment_wrap  # noqa: E402

SCRIPT = os.path.join(SCRIPTS, "comment_wrap.py")


def run_cli(*argv):
    proc = subprocess.run([sys.executable, SCRIPT, *argv],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def wrap_module(body):
    return "{ lib, ... }:\n{\n" + body + "\n}\n"


class LexerTests(unittest.TestCase):
    def kinds(self, text):
        return sorted(comment_wrap.comment_indents(text).items())

    def test_plain_comment_lines(self):
        text = "{\n  # one\n    # two\n  x = 1; # trailing\n}"
        self.assertEqual(self.kinds(text), [(1, 2), (2, 4)])

    def test_hash_inside_double_quote_is_not_a_comment(self):
        text = '{\n  x = "a # not comment";\n  # real\n}'
        self.assertEqual(self.kinds(text), [(2, 2)])

    def test_shell_comments_inside_indented_string_ignored(self):
        text = "".join([
            "{\n",
            "  programs.zsh.initContent = ''\n",
            "    # a very long shell comment line that goes well past eighty",
            " columns indeed\n",
            "    export PATH=${pkgs.hello}/bin:$PATH\n",
            "  '';\n",
            "}\n",
        ])
        self.assertEqual(self.kinds(text), [])

    def test_string_escapes(self):
        # \" stays in the string; ''${ stays in the string; ''' too.
        text = ''.join([
            "{\n",
            '  a = "x \\" # y";\n',
            "  b = ''\n",
            "    ''${not_a_closing} '''\n",
            "    # still shell text, long enough to wrap if it were touched",
            " xxxxxx\n",
            "  '';\n",
            "  # real comment\n",
            "}\n",
        ])
        self.assertEqual(self.kinds(text), [(6, 2)])

    def test_interpolation_with_braces_and_comment(self):
        text = "".join([
            "{\n",
            "  x = ''\n",
            "    ${ toString (if a then { b = 1; } else { }) }\n",
            "    ${ lib.optionalString true # inline comment with }\n",
            "      \"text\"\n",
            "    }\n",
            "    # shell comment, long enough that wrapping it would corrupt",
            " the dotfile xx\n",
            "  '';\n",
            "}\n",
        ])
        # None of the string/interpolation lines may read as comments.
        self.assertEqual(self.kinds(text), [])


class MovingLimitTests(unittest.TestCase):
    def test_limit_moves_with_indent(self):
        # 78 content columns at indent 4: exactly at the moving limit.
        base = "    # " + "w " * 38 + "ww"
        self.assertEqual(len(base), 84)
        self.assertEqual(
            comment_wrap.over_limit(wrap_module(f"  {base}\n  y = 1;"), 80),
            [])
        over = "    # " + "w " * 38 + "www"
        found = comment_wrap.over_limit(
            wrap_module(f"  {over}\n  y = 1;"), 80)
        self.assertEqual(len(found), 1)

    def test_indent_zero_limit_is_eighty(self):
        line = "# " + "w " * 38 + "ww"
        self.assertEqual(
            comment_wrap.over_limit(wrap_module(f" {line}\n"), 80), [])
        line = "# " + "w " * 38 + "www"
        self.assertNotEqual(
            comment_wrap.over_limit(wrap_module(f" {line}\n"), 80), [])


class FixTests(unittest.TestCase):
    def fix(self, text):
        return comment_wrap.fix_text(text, 80)

    def test_reflows_broken_prose_paragraph(self):
        text = wrap_module("  # the first line is short\n"
                           "  # " + "word " * 24 + "end\n"
                           "  y = 1;\n")
        fixed = self.fix(text)
        self.assertEqual(comment_wrap.over_limit(fixed, 80), [])
        # Words survive: joining and refilling must not lose any. Compare
        # comment contents only -- the `#` markers a join removes are not
        # words.
        def contents(t):
            indents = comment_wrap.comment_indents(t)
            return [comment_wrap.content_of(t.split("\n")[ln], ind)
                    for ln, ind in sorted(indents.items())]
        self.assertEqual(" ".join(contents(text)), " ".join(contents(fixed)))

    def test_paragraph_split_by_bare_hash_line(self):
        text = wrap_module("  # first paragraph\n"
                           "  #\n"
                           "  # second " + "para " * 30 + "\n")
        fixed = self.fix(text)
        lines = fixed.split("\n")
        self.assertEqual(lines[2], "  # first paragraph")
        self.assertEqual(lines[3], "  #")
        self.assertLessEqual(len(lines[4]), 82)  # moving limit at indent 2

    def test_fix_is_idempotent(self):
        text = wrap_module("  # " + "word " * 30 + "end\n")
        once = self.fix(text)
        self.assertEqual(self.fix(once), once)

    def test_never_touches_string_content(self):
        shell = "".join([
            "{\n",
            "  programs.zsh.initContent = ''\n",
            "    # " + "shell comment " * 10 + "\n",
            "    if [[ -n $X ]]; then # " + "trailing " * 12 + "\n",
            "    fi\n",
            "  '';\n",
            "}\n",
        ])
        self.assertEqual(self.fix(shell), shell)

    def test_summary_line_reported_not_rewritten(self):
        text = wrap_module("  {\n"
                           "    # summary: " + "quite long summary text " * 5 + "\n"
                           "    y = 1;\n"
                           "  };\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["summary"])
        self.assertEqual(self.fix(text), text)

    def test_summary_line_pinned_lead_refilled(self):
        # The summary line itself fits; the lead under it does not. The
        # fix must keep the summary line verbatim and refill the rest.
        text = wrap_module("  {\n"
                           "    # summary: short enough for one line.\n"
                           "    # " + "lead prose word " * 12 + "end\n"
                           "    y = 1;\n"
                           "  };\n")
        summary_line = "    # summary: short enough for one line."
        self.assertEqual([cls for _, _, cls, _, _ in
                          comment_wrap.over_limit(text, 80)], ["prose"])
        fixed = self.fix(text)
        self.assertIn(summary_line + "\n", fixed)
        self.assertEqual(comment_wrap.over_limit(fixed, 80), [])

    def test_bullet_reported_not_rewritten(self):
        text = wrap_module("  # - an item that runs " + "long " * 25 + "\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["bullet"])
        self.assertEqual(self.fix(text), text)

    def test_url_line_exempt_and_untouched(self):
        text = wrap_module(
            "  # see the upstream note at https://github.com/example/repo/"
            "blob/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/x.md\n")
        self.assertEqual(comment_wrap.over_limit(text, 80), [])
        self.assertEqual(self.fix(text), text)

    def test_aligned_table_exempt_and_untouched(self):
        text = wrap_module(
            '  # "extendedglob"                       # Extended globbing '
            "allows using regular expressions with *\n")
        self.assertEqual(comment_wrap.over_limit(text, 80), [])
        self.assertEqual(self.fix(text), text)

    def test_banner_exempt(self):
        text = wrap_module("  #" + "#" * 60 + "\n")
        self.assertEqual(comment_wrap.over_limit(text, 80), [])

    def test_banner_splits_the_paragraph(self):
        # A decorative rule inside a comment block separates paragraphs;
        # the prose after it must still be checked and fixed.
        text = wrap_module("  # " + "\u2500" * 40 + "\n"
                           "  # " + "word " * 30 + "end\n")
        fixed = self.fix(text)
        self.assertEqual(fixed.split("\n")[2].strip(),
                         "# " + "\u2500" * 40)
        self.assertEqual(comment_wrap.over_limit(fixed, 80), [])

    def test_em_dash_led_continuation_is_prose(self):
        # `-- ` leading a wrapped line is the house em-dash, not a flag.
        text = wrap_module("  # the aggregate import, as one\n"
                           "  # -- added 2026-08-27, folding what used to "
                           "be seven separate imports here into one place\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["prose"])
        fixed = self.fix(text)
        self.assertEqual(comment_wrap.over_limit(fixed, 80), [])

    def test_tilde_led_content_is_prose(self):
        text = wrap_module("  # " + "~/.zcompdump and ~/.config/zsh go "
                           "away when the cache is cleared, " * 2 + "yes\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["prose"])
        self.assertEqual(
            comment_wrap.over_limit(self.fix(text), 80), [])

    def test_broken_backtick_span_reported_not_rewritten(self):
        # The span opens on the first line and closes on the second; a
        # join would swallow a space into the quoted message.
        text = wrap_module("  # the failure text `Failed to register with "
                           "host portal QDBusError(\"org.freedesktop\n"
                           "  # connection is already associated\")` shows "
                           "up in the journal twice per session\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["broken-span"])
        self.assertEqual(self.fix(text), text)

    def test_overflow_token_exempt_not_rewritten(self):
        token = "`" + "x" * 90 + "`"
        text = wrap_module(f"  # see {token} for the shape\n")
        # A token wider than any wrapped line has no mechanical fix, so
        # it sits exempt like a URL line.
        self.assertEqual(comment_wrap.over_limit(text, 80), [])
        self.assertEqual(self.fix(text), text)

    def test_aligned_continuation_reported_not_rewritten(self):
        text = wrap_module("  #         related to the equally unexplained "
                           "PYTHON = \"PYTHON\" in shell-env.nix, which "
                           "nothing in this tree sets on purpose.\n")
        found = comment_wrap.over_limit(text, 80)
        self.assertEqual([cls for _, _, cls, _, _ in found], ["shape"])
        self.assertEqual(self.fix(text), text)


class CliTests(unittest.TestCase):
    def write_module(self, dir_path, body):
        path = dir_path / "mod.nix"
        path.write_text(wrap_module(body))
        return str(path)

    def test_check_exit_codes(self):
        with tempfile.TemporaryDirectory() as tmp:
            clean = self.write_module(pathlib.Path(tmp),
                                      "  # short\n  y = 1;\n")
            self.assertEqual(run_cli(clean)[0], 0)
            dirty = self.write_module(
                pathlib.Path(tmp),
                "  # " + "word " * 30 + "end\n  y = 1;\n")
            code, out = run_cli(dirty)
            self.assertEqual(code, 1)
            self.assertIn("[prose]", out)

    def test_diff_prints_and_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.write_module(
                pathlib.Path(tmp),
                "  # " + "word " * 30 + "end\n  y = 1;\n")
            before = pathlib.Path(path).read_text()
            code, out = run_cli("--diff", path)
            self.assertEqual(code, 0, out)  # nothing left for hand work
            self.assertIn("+++ " + path, out)
            self.assertEqual(pathlib.Path(path).read_text(), before)

    def test_fix_then_check_clean(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = self.write_module(
                pathlib.Path(tmp),
                "  # " + "word " * 30 + "end\n  y = 1;\n")
            code, out = run_cli("--fix", path)
            self.assertEqual(code, 0, out)  # nothing left for hand work
            code, out = run_cli(path)
            self.assertEqual(code, 0, out)

    def test_module_default_reports_nothing_on_clean_tree_dir(self):
        # An empty target dir exercises the no-files error path.
        with tempfile.TemporaryDirectory() as tmp:
            code, _ = run_cli(tmp)
            self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
