#!/usr/bin/env python3
"""Fixture tests for check_wiki.py's `rules` check (path-scoped
`.agents/rules/*.md`). Against the real tree a clean run proves only that
today's rules are fine, not that a dead glob or an unlisted rule would be
caught -- so this builds a small git repo in a temp directory, breaks one
thing at a time, and asserts the finding. Pure stdlib + git; runs in
`just preflight` and so in CI.
"""
import pathlib, subprocess, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import check_wiki  # noqa: E402

GOOD_RULE = '''---
paths:
  - "src/**/*.nix"
  - "**/*.{sh,py}"
---

# A rule
'''


class RulesCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.write('src/a/b.nix', '{ }\n')
        self.write('tools/run.sh', 'true\n')
        self.write('AGENTS.md', 'See `.agents/rules/good.md`.\n')
        self.write('.agents/rules/good.md', GOOD_RULE)
        subprocess.run(['git', '-C', str(self.root), 'add', '-A'], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def findings(self):
        return check_wiki.check_rules(self.root)

    def test_clean(self):
        self.assertEqual(self.findings(), [])

    def test_dead_glob(self):
        self.write('.agents/rules/good.md',
                   GOOD_RULE.replace('src/**/*.nix', 'nope/**'))
        f = self.findings()
        self.assertEqual(len(f), 1)
        self.assertIn("DEAD RULE GLOB", f[0])
        self.assertIn("'nope/**'", f[0])

    def test_untracked_match_is_dead(self):
        # A file on disk but not in git doesn't count: flakes and clones
        # only ever see tracked files.
        self.write('.agents/rules/good.md',
                   GOOD_RULE.replace('src/**/*.nix', 'new/*.nix'))
        self.write('new/x.nix', '{ }\n')
        self.assertIn("DEAD RULE GLOB", self.findings()[0])

    def test_unlisted(self):
        self.write('AGENTS.md', 'No pointer here.\n')
        self.assertIn("UNLISTED RULE", self.findings()[0])

    def test_no_frontmatter(self):
        self.write('.agents/rules/good.md', '# A rule\n')
        self.assertIn("RULE FRONTMATTER", self.findings()[0])

    def test_unknown_key(self):
        self.write('.agents/rules/good.md',
                   GOOD_RULE.replace('---\npaths:', '---\npaths:\n  globs: x', 1))
        self.assertTrue(any("unexpected line" in f for f in self.findings()))

    def test_glob_shapes(self):
        rx = check_wiki.glob_regex
        self.assertTrue(rx('**/*.nix').match('a.nix'))
        self.assertTrue(rx('**/*.nix').match('x/y/a.nix'))
        self.assertFalse(rx('a/*/hw/**').match('a/b/c/hw/x'))
        self.assertTrue(rx('a/*/hw/**').match('a/b/hw/x/y'))
        self.assertTrue(rx('*.{sh,py}').match('t.py'))
        self.assertFalse(rx('*.md').match('wiki/x.md'))


if __name__ == '__main__':
    unittest.main()
