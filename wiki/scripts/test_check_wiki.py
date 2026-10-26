#!/usr/bin/env python3
"""Fixture tests for check_wiki.py's `rules` check (path-scoped
`.agents/rules/*.md`) and the lessons-map half of its `lessons` check
(`.agents/lessons-map.toml`, validated by .agents/hooks/lessons_map.py). Against the real tree a clean run proves only that
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


GOOD_MAP = '''
[[topic]]
id = "area"
paths = ["src/**/*.nix", "**/*.{sh,py}"]
rules = "good.md"
skill = "s"
lessons = [1]
remind = "a reminder"

[[topic]]
id = "cmd"
command = 'lsblk'
see = "AGENTS.md"
remind = "another"
'''


class LessonsMapCheck(unittest.TestCase):
    """lessons_map.validate(), each way the map can drift from the repo."""
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        for rel, text in (('src/a/b.nix', '{ }\n'), ('tools/run.sh', 'true\n'),
                          ('AGENTS.md', 'x\n'), ('.agents/rules/good.md', GOOD_RULE),
                          ('.agents/skills/s/SKILL.md', 'x\n')):
            p = self.root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)

    def tearDown(self):
        self.tmp.cleanup()

    def findings(self, map_text, lessons=frozenset({1})):
        (self.root / '.agents' / 'lessons-map.toml').write_text(map_text)
        return check_wiki.lessons_map.validate(
            self.root, ['src/a/b.nix', 'tools/run.sh'], set(lessons),
            check_wiki.rule_globs(self.root))

    def assertFinds(self, map_text, needle, **kw):
        found = self.findings(map_text, **kw)
        self.assertTrue(any(needle in f for f in found), found)

    def test_good_map_is_clean(self):
        self.assertEqual(self.findings(GOOD_MAP), [])

    def test_dead_glob(self):
        self.assertFinds(GOOD_MAP.replace('"src/**/*.nix", ', '"src/**/*.nix", "gone/**", '),
                         "matches no tracked file")

    def test_rules_paths_drift(self):
        self.assertFinds(GOOD_MAP.replace(', "**/*.{sh,py}"', ''),
                         "differ from .agents/rules/good.md")

    def test_rules_file_without_topic(self):
        self.assertFinds(GOOD_MAP.replace('rules = "good.md"\n', ''),
                         "good.md has no topic")

    def test_missing_skill_lesson_see(self):
        self.assertFinds(GOOD_MAP.replace('skill = "s"', 'skill = "t"'),
                         "skill `t` does not exist")
        self.assertFinds(GOOD_MAP, "§1 has no entry", lessons=set())
        self.assertFinds(GOOD_MAP.replace('see = "AGENTS.md"', 'see = "NOPE.md"'),
                         "NOPE.md does not exist")

    def test_shape(self):
        self.assertFinds(GOOD_MAP.replace('remind = "another"', 'colour = 1'),
                         "unknown key `colour`")
        self.assertFinds(GOOD_MAP.replace("command = 'lsblk'", "command = '(lsblk'"),
                         "not a valid regex")
        self.assertFinds(GOOD_MAP.replace('remind = "a reminder"', ''),
                         "no `remind` text")
        self.assertFinds(GOOD_MAP.replace('see = "AGENTS.md"\n', ''),
                         "names no skill, rules file, lesson")
        self.assertFinds(GOOD_MAP + '\n[[topic]]\nid = "area"\npaths = ["src/**/*.nix"]'
                         '\nsee = "AGENTS.md"\nremind = "x"\n', "duplicate id")
        self.assertFinds('[[topic\n', "LESSONS MAP SYNTAX")


class DocRefsCheck(unittest.TestCase):
    """Each rule of `docrefs` against a case it must catch and one it must
    leave alone."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.write('.agents/scripts/agent.just', 'where *args:\n    @true\n')
        self.write('.agents/skills/real-skill/SKILL.md', '# s\n')
        self.write('wiki/target.md', '# Target\n\n## Ad hoc restic commands\n')
        self.write('AGENTS.md', 'clean\n')

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def findings(self, doc):
        self.write('wiki/doc.md', doc)
        return check_wiki.check_docrefs(self.root)

    def test_unknown_helper_caught(self):
        f = self.findings('Run `just agent nope`.\n')
        self.assertTrue(any(x.startswith('UNKNOWN HELPER') for x in f), f)

    def test_known_helper_and_placeholder_pass(self):
        self.assertEqual(self.findings(
            'Run `just agent where` or `just agent where <n>` or `just agent`.\n'), [])

    def test_skill_path_caught(self):
        f = self.findings('See `.agents/skills/gone/SKILL.md`.\n')
        self.assertTrue(any(x.startswith('UNKNOWN SKILL') for x in f), f)

    def test_plain_hyphenated_skill_caught(self):
        f = self.findings('Follow skill no-such-skill here.\n')
        self.assertTrue(any(x.startswith('UNKNOWN SKILL') for x in f), f)

    def test_real_skill_and_git_log_pass(self):
        self.assertEqual(self.findings(
            'See `.agents/skills/real-skill/SKILL.md` and skill real-skill.\n'
            '`git log -- .agents/skills/removed-one` has it.\n'), [])

    def test_missing_section_caught(self):
        f = self.findings('See [target.md](target.md)\'s "Nonexistent part" section.\n')
        self.assertTrue(any(x.startswith('UNKNOWN SECTION') for x in f), f)

    def test_existing_section_passes(self):
        self.assertEqual(self.findings(
            'See `target.md`\'s "Ad hoc restic commands" section.\n'), [])

    def test_quote_belonging_to_other_page_not_flagged(self):
        self.assertEqual(self.findings(
            'The "Elsewhere" section of the `real-skill` skill, see `target.md`.\n'), [])

    def bare(self, doc, rel='wiki/doc.md'):
        self.write(rel, doc)
        return [x for x in check_wiki.check_docrefs(self.root)
                if x.startswith('BARE COUNT')]

    def test_bare_count_caught(self):
        self.assertTrue(self.bare('All four files under x/ do y.\n'))
        self.assertTrue(self.bare('There are 12 nix modules here.\n'))

    def test_bare_count_accompanied_or_exempt_passes(self):
        for doc in (
            'The four hosts are `a`, `b`, `c`, `d`.\n',
            'There are four files:\n\n- a\n',
            'As of 2026-10-01 there are four files.\n',
            'Four hosts at the time, as of the merge.\n',
            'Four files here. <!-- count-ok: measurement -->\n',
            'It said "all four files" once.\n',
            'Run `all four files` today.\n',
            '```\nfour files\n```\n',
            'Reported 119 of 160 modules as orphans.\n',
            'Two modules with one name collide.\n',
            'Four colours and three people.\n',
            '<!-- generated:t -- x -->\nfour files\n<!-- /generated -->\n',
        ):
            self.assertEqual(self.bare(doc), [], doc)

    def test_bare_count_skips_narrative_paths(self):
        self.assertEqual(self.bare('All four files.\n',
                                   'wiki/lessons-learned/1-x.md'), [])
        self.assertEqual(self.bare('All four files.\n', 'wiki/x-history.md'), [])

    def test_moved_path_caught(self):
        f = self.findings('Guards live in `.claude/hooks/x.sh`.\n')
        self.assertTrue(any(x.startswith('MOVED PATH') for x in f), f)

    def test_new_path_passes(self):
        self.assertEqual(self.findings('Guards live in `.agents/hooks/x.sh`.\n'), [])


class FenceHandling(unittest.TestCase):
    """`_just_mentions_in_skill` reads bare `just <recipe>` only inside a
    fenced code block, so what counts as a fence decides which mentions get
    checked. check_wiki.py once defined FENCE twice with different patterns;
    the later one silently won for every function above it."""

    def mentions(self, text):
        return check_wiki._just_mentions_in_skill(text)

    def test_indented_fence_in_list_item(self):
        self.assertIn('indented-recipe', self.mentions(
            '1. step\n\n   ```sh\n   just indented-recipe\n   ```\n'))

    def test_tilde_fence(self):
        self.assertIn('tilde-recipe', self.mentions(
            '~~~\njust tilde-recipe\n~~~\n'))

    def test_longer_fence_is_not_closed_by_a_shorter_one(self):
        self.assertIn('inner-recipe', self.mentions(
            '````md\n```\njust inner-recipe\n```\n````\n'))

    def test_other_fence_character_does_not_close(self):
        self.assertIn('mixed-recipe', self.mentions(
            '```\n~~~\njust mixed-recipe\n```\n'))

    def test_four_space_indent_is_not_a_fence(self):
        self.assertNotIn('prose-recipe', self.mentions(
            '    ```\njust prose-recipe\n'))

    def test_prose_after_closing_fence_is_not_read(self):
        self.assertNotIn('after-recipe', self.mentions(
            '```\nx\n```\njust after-recipe\n'))


if __name__ == '__main__':
    unittest.main()
