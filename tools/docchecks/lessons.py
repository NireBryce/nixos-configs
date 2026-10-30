"""lessons: the lessons index and the lessons map, in one check.

The index half: wiki/agent-lessons-learned.md is an index, one
`- **§N** [title](...) — rule.` entry per lesson, each linking its own
`<N>-<slug>.md` article and carrying `Home:` and `Enforced:` fields, with
an article for every § from 1 to the top -- so an entry can't land
without saying where its rule lives. The fields' contents are validated
by the checks that already read backticked recipe and skill names and
relative links; this one only guarantees they exist.

The map half validates .agents/lessons-map.toml through
.agents/hooks/lessons_map.validate -- imported from the hooks directory,
NOT copied here. The map's `paths:` glob semantics is deliberately
single-sourced: the lesson-reminder hook, `just agent lessons` and this
check are its three readers, and three copies of the semantics could
disagree about what a rule or a topic selects.
"""
import re
import sys

from factcheck.findings import Finding
from factcheck.gitfiles import tracked_files
from factcheck.registry import check
from factcheck.checks.rules import RULE_FRONTMATTER, RULE_PATH_ITEM, \
    rule_files

PAGE = 'wiki/agent-lessons-learned.md'
ART_DIR = 'wiki/agent-lessons-learned'
# Not a lesson: explains the folder to a person reading it.
HUMAN_README = '0-human-README.md'

ENTRY = re.compile(
    r'^- \*\*§(\d+)\*\* \[[^\]]+\]\((agent-lessons-learned/[^)]+)\) — .+$')
ARTICLE = re.compile(r'^(\d+)-[a-z0-9-]+\.md$')


def rule_globs(root):
    """{rules filename: [globs]} from each rule file's frontmatter,
    leniently -- check_rules reports a malformed one."""
    out = {}
    base = root / '.agents' / 'rules'
    for path in rule_files(root, '.agents/rules'):
        m = RULE_FRONTMATTER.match(path.read_text())
        lines = m.group(1).splitlines() if m else []
        out[path.relative_to(base).as_posix()] = [
            i.group(1) for i in map(RULE_PATH_ITEM.match, lines) if i]
    return out


@check('lessons', order=150)
def check_lessons(root, cfg):
    sys.path.insert(0, str(root / '.agents' / 'hooks'))
    import lessons_map  # noqa: E402  (the shared reader; see docstring)

    page = root / PAGE
    art_dir = root / ART_DIR
    findings = []
    entries = {}
    for line in page.read_text().splitlines():
        if not line.startswith('- **§'):
            continue
        m = ENTRY.match(line)
        if not m:
            findings.append(Finding('MALFORMED LESSON', PAGE, line[:70]))
            continue
        n, link = int(m.group(1)), m.group(2)
        if n in entries:
            findings.append(Finding(
                'DUPLICATE LESSON', PAGE, f"§{n} has two entries"))
        entries[n] = link
        if not link.startswith(f'agent-lessons-learned/{n}-'):
            findings.append(Finding(
                'LESSON LINK', PAGE, f"§{n} links {link}, not its own "
                                     f"article"))
        for field in ('Home: ', 'Enforced: '):
            if f'. {field}' not in line:
                findings.append(Finding(
                    'LESSON FIELD', PAGE, f"§{n} has no `{field.strip()}`"))

    articles = {}
    for p in sorted(art_dir.glob('*.md')):
        if p.name == HUMAN_README:
            continue
        m = ARTICLE.match(p.name)
        if not m:
            findings.append(Finding(
                'LESSON ARTICLE NAME', str(p), "not `<N>-<slug>.md`"))
            continue
        n = int(m.group(1))
        if n in articles:
            findings.append(Finding(
                'DUPLICATE ARTICLE', str(p),
                f"§{n} already has {articles[n].name}"))
        articles[n] = p
        if not p.read_text().startswith(f'# {n}. '):
            findings.append(Finding(
                'LESSON ARTICLE TITLE', str(p),
                f"title isn't `# {n}. ...`"))

    top = max([*entries, *articles], default=0)
    for n in range(1, top + 1):
        if n not in entries:
            findings.append(Finding('MISSING LESSON', PAGE, f"no entry for §{n}"))
        if n not in articles:
            findings.append(Finding(
                'MISSING ARTICLE', ART_DIR, f"no {n}-*.md for §{n}"))

    findings += lessons_map.validate(root, tracked_files(root),
                                     set(entries), rule_globs(root))
    return findings
