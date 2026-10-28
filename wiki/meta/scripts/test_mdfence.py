#!/usr/bin/env python3
"""mdfence.py against CommonMark's fence rules, one rule per test. Pure
stdlib; runs in `just preflight` beside test_check_wiki.py."""
import pathlib, sys, unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import mdfence  # noqa: E402


def fenced(text):
    return [line for _, line, f in mdfence.iter_lines(text) if f]


def kinds(text):
    return [k for _, _, k in mdfence.scan_lines(text)]


class Fences(unittest.TestCase):
    def test_backtick_and_tilde_fences(self):
        self.assertEqual(fenced('a\n```\nx\n```\nb\n'), ['```', 'x', '```'])
        self.assertEqual(fenced('a\n~~~\nx\n~~~\nb\n'), ['~~~', 'x', '~~~'])

    def test_kinds(self):
        self.assertEqual(kinds('a\n```sh\nx\n```\nb\n'),
                         ['text', 'open', 'body', 'close', 'text'])

    def test_indent_up_to_three(self):
        self.assertEqual(fenced('   ```\nx\n   ```\n'), ['   ```', 'x', '   ```'])
        self.assertEqual(fenced('    ```\nx\n'), [])

    def test_closing_fence_must_be_as_long(self):
        self.assertEqual(len(fenced('````\n```\nx\n```\n````\ny\n')), 5)

    def test_closing_fence_must_be_same_character(self):
        self.assertEqual(len(fenced('```\n~~~\nx\n```\ny\n')), 4)

    def test_closing_fence_takes_no_info_string(self):
        self.assertEqual(len(fenced('```\n```sh\nx\n```\ny\n')), 4)

    def test_backtick_info_string_cannot_hold_a_backtick(self):
        self.assertEqual(fenced('```foo``` bar\nx\n'), [])
        self.assertEqual(fenced('~~~foo``` bar\nx\n'), ['~~~foo``` bar', 'x'])

    def test_unclosed_fence_runs_to_the_end(self):
        self.assertEqual(fenced('```\nx\ny\n'), ['```', 'x', 'y'])

    def test_blank_fences_keeps_offsets(self):
        text = 'a\n```\nxy\n```\nb\n'
        out = mdfence.blank_fences(text)
        self.assertEqual(len(out), len(text))
        self.assertEqual(out.splitlines(), ['a', '   ', '  ', '   ', 'b'])


if __name__ == '__main__':
    unittest.main()
