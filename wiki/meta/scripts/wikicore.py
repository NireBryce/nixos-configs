#!/usr/bin/env python3
"""Plumbing shared by the wiki scripts: which markdown files exist, the
page-header date line, rule frontmatter, and the registry every check
registers itself in (`@check`).

check_docs.py and wiki_gen.py both register checks here, so neither has to
import the other: wiki_gen used to import check_docs for its parsers while
check_docs imported wiki_gen (lazily, to dodge the cycle) to run its check.
"""
import datetime
import re

def wiki_md(root, pattern='*.md'):
    """Every real markdown file under wiki/, symlinks excluded.

    Each wiki directory carries a README.md symlink to its 00-INDEX.md so
    GitHub still sees a filename it recognizes. Those are the same bytes
    under a second name: scanned as documents they double every word
    count and invent a README.md/README-for-agents.md sibling pair nobody
    wrote. Every check that walks wiki/ goes through here so a new one
    can't reintroduce that by globbing directly.
    """
    return sorted(
        p for p in root.joinpath('wiki').rglob(pattern) if not p.is_symlink()
    )


def rule_files(root):
    """`.agents/rules/*.md`, recursive -- Claude Code discovers rules in
    subdirectories too. `.claude/rules` is a symlink to `.agents/rules`, so
    this is the one real copy."""
    rules = root / '.agents' / 'rules'
    return sorted(rules.rglob('*.md')) if rules.is_dir() else []


def doc_files(root):
    """Every markdown file the claim checks scan: all of wiki/ (recursive),
    AGENTS.md itself, and the path-scoped rules AGENTS.md points at -- the
    files outside wiki/ that duplicate wiki-shaped claims verbatim
    (CLAUDE.md is a symlink to AGENTS.md, so checking the target once
    covers both names).

    Symlinks under wiki/ are skipped for that same reason: each directory's
    README.md is a symlink to its 00-INDEX.md, kept so GitHub still has a
    filename it recognizes. Scanned as documents they would double every
    page's word count and invent a README.md/README-for-agents.md sibling
    pair that no one wrote."""
    return wiki_md(root) + [root / 'AGENTS.md'] + rule_files(root)


# The exact line styleguide.md requires right after a page's title:
# `_Last modified: 2026-09-06_`. Anchored to the whole line -- a stray
# trailing word or missing underscore is exactly the kind of drift the
# checks exist to catch, same reasoning as the Contents items being just as
# strict about their own line shape.
LAST_MODIFIED_LINE = re.compile(r'^_Last modified: (\d{4}-\d{2}-\d{2})_\s*$')


def last_modified(text):
    """The page's `_Last modified:_` date, or None. check_dates is what
    reports a page missing the line at all; this just can't compare without
    it."""
    for line in text.splitlines()[:6]:
        m = LAST_MODIFIED_LINE.match(line)
        if m:
            return datetime.date.fromisoformat(m.group(1))
    return None


# A path-scoped rule's frontmatter, strict on purpose: it must open the file.
RULE_FRONTMATTER = re.compile(r'\A---\n(.*?)\n---\n', re.S)


# --- the check registry ---------------------------------------------------

CHECKS = {}
_UNORDERED = 10_000


def check(name, order=None):
    """Registers `fn(root) -> [finding]` as the subcommand `name`; `check_docs.py
    check` runs every registered check. A check that isn't registered isn't a
    subcommand and isn't in `check`, and a check that is registered can't be
    missing from either -- there is no second list to keep in step.

    `order` fixes where its findings print in `check`'s combined output; a
    check without one runs after the ordered ones, in registration order."""
    def register(fn):
        # flake/scripts/modules.py execs check_docs.py afresh for each call,
        # so the same function arrives again as a new object: that replaces
        # its entry; a different function under a taken name is the bug.
        old = CHECKS.get(name)
        if old is not None:
            same = (old[2].__module__, old[2].__qualname__) == (fn.__module__, fn.__qualname__)
            assert same, f"check {name!r} registered twice"
        CHECKS[name] = (
            _UNORDERED if order is None else order,
            old[1] if old else len(CHECKS), fn)
        return fn
    return register


def registered():
    """[(name, fn)] in run order."""
    return [(n, fn) for n, (_, _, fn) in sorted(CHECKS.items(), key=lambda kv: kv[1][:2])]
