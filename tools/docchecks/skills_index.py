"""The skills index: one generated row per skill in `.agents/skills/`.

The table on `wiki/meta/skills-index.md` is derived from each skill's
frontmatter (`description` and `when_to_use`), so adding a skill, renaming
one or rewording its description changes the table's source and nothing
else has to be edited. The `generated` check fails when the table is stale;
`just wiki-gen` rewrites it. wiki/meta/scripts/wiki_gen.py is the writer and
registers the same region (`skill_rows` there); this plugin is the lint, so
the two must render identically, as with nixos_regions.py's regions.

Rows are sorted by name. Skills that share a prefix (`new-*`, `extract-*`,
`wiki-*`) end up adjacent, which is the only grouping the table has: the
skills directory is flat on purpose (see the page).
"""
import re

from factcheck import genregions
from factcheck.genregions import GenError, Region

SKILLS = '.agents/skills'
PAGE = 'wiki/meta/skills-index.md'
LINK = '../../' + SKILLS + '/{name}/SKILL.md'
FRONTMATTER = re.compile(r'\A---\n(.*?)\n---\n', re.S)


def frontmatter(text):
    """{key: value} of the plain `key: value` lines in the leading block.
    Skill frontmatter holds only plain scalars (the skill-files check
    enforces it), so no YAML parser is needed."""
    m = FRONTMATTER.match(text)
    out = {}
    for line in (m.group(1).splitlines() if m else []):
        key, sep, value = line.partition(': ')
        if sep:
            out[key.strip()] = value.strip()
    return out


def _cell(text):
    return text.replace('|', '\\|')


def skill_rows(root):
    base = root / SKILLS
    skills = sorted(p for p in base.glob('*/SKILL.md'))
    if not skills:
        raise GenError(f'no SKILL.md files under {SKILLS}/')
    for path in skills:
        name = path.parent.name
        fm = frontmatter(path.read_text())
        if not fm.get('description'):
            raise GenError(f'{SKILLS}/{name}/SKILL.md has no description')
        yield name, {
            'Skill': f"[`{name}`]({LINK.format(name=name)})",
            'Does': _cell(fm['description']),
            'Use when': _cell(fm.get('when_to_use', '')),
        }


def register():
    genregions.register(Region(
        'skills-index', PAGE,
        f'the frontmatter of each {SKILLS}/*/SKILL.md',
        ['Skill', 'Does', 'Use when'], 'Skill', [], skill_rows,
        tool_name='`just wiki-gen`'))


register()
