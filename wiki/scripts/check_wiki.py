#!/usr/bin/env python3
"""Static checks of wiki/ (and AGENTS.md, the one file outside wiki/ that
duplicates wiki-shaped claims verbatim -- see `doc_files`) against the actual
module tree, for authoritative claims that silently go stale after a
refactor -- a category moved, a host stopped importing something, a recipe
got renamed. Same motivation as `flake/scripts/modules.py`: nothing about
`nix flake check` or `just modules` reads prose, so a doc can say something
the repo has stopped agreeing with and nothing catches it.

This does NOT replace human judgement about whether a change actually needs a
wiki update -- see skill `wiki-sync` for that. It only catches the mechanical
case: a claim that's phrased as a checkable fact (an import list, a path) and
no longer matches what's on disk. Historical claims ("added 2026-08-21 as
`nire/foo/`") are deliberately NOT the target -- this repo keeps those on
purpose (CLAUDE.md, "a bug recorded in a comment stays in the file"), and a
script can't tell historical prose from a live claim by itself, so it checks
structured, extractable facts only:

  imports   For each host's actual bare-category import list (parsed the same
            way `modules.py` parses aggregates) and each `wiki/categories/
            <name>.md` that exists for one of those categories, checks that
            the page's "## Imported by" section text mentions the host by
            name, and flags a host name mentioned there that the host's
            actual import list does not contain. Heuristic, not exact --
            prose is matched by substring, so a page phrasing a host's
            *absence* ("not durandal") will mention the name too; read a
            finding before trusting it, same as `modules.py`'s own tools ask.
            Categories with no wiki page (nirePackages/* subcategories,
            nireHost/* bundles -- see categories/README.md's own exclusion
            list) are silently skipped: nothing to check them against.

  table     Checks categories/README.md's "## Index" table -- the one place
            that summarizes every category in one row each -- against the
            tree. Directory and Class(es) are fully mechanical (a path, and
            the union of `flake.modules.<class>` declarations found anywhere
            under that path) so a mismatch is always a real finding, not a
            heuristic; Imported by reuses the same substring/blanket-phrase
            heuristic as `imports` above, just applied to the table cell
            instead of a page's own section. This is the second mechanical
            check `check`'s docstring used to say would show up here
            eventually -- unlike the per-category file COUNT that used to
            live in this same table (a "Members" column, removed 2026-08-29
            once hand-incrementing it on every module add/remove outweighed
            what it told a reader that "read the directory" didn't already,
            see wiki-sync and CLAUDE.md's Safety section), Directory and
            Class(es) aren't a running tally that grows every time something
            nearby changes -- they only drift on an actual category move or
            reclassification, which is exactly the kind of stale-claim-after-
            a-refactor case this whole script exists for.

  hosts     Checks wiki/hosts.md's "The hosts" table -- Host, Class, and
            Wipes `/root`? -- against `nireHost/hosts.nix` (the actual
            `nixosConfigurations`/`darwinConfigurations` entries, read
            independently of this script's own HOSTS constant below, which
            exists for a narrower reason and is a second hand-maintained
            list this incidentally cross-checks) and, for Wipes `/root`?,
            against whether the host's own import list actually contains
            `impermanence`. Role is free prose and not checked. This is the
            table CLAUDE.md's Safety section calls out by name as something
            to read rather than trust a stale copy of -- exactly the kind of
            claim worth making a script watch instead of a human remembering
            to.

  recipes   Every backtick `just <recipe...>` mention across wiki/ and
            AGENTS.md against .justfile's own recipe names -- a rename or
            removal silently breaks every doc that told someone to run the
            old name, and nothing about `just` itself would complain until
            someone actually tried it.

  skills    Every "skill `name`"/"`name` skill" mention across wiki/ and
            AGENTS.md against real `.claude/skills/<name>/` directories --
            same shape as `recipes`, for a skill rename instead.

  secrets   The "`.sops.yaml` ... enrolls `host`, `host`, ... —" claim
            (wiki/impermanence-and-secrets.md and AGENTS.md's Safety section
            both make it, in the same shape, and AGENTS.md's own text admits
            "this paragraph has been stale before") against .sops.yaml's
            actual key anchors. Fully mechanical in both directions -- unlike
            Imported by, there's no legitimate "named to say it's absent"
            case for an enrollment list.

  check     Runs all six of the above.

    check_wiki.py imports  [repo-root]
    check_wiki.py table    [repo-root]
    check_wiki.py hosts    [repo-root]
    check_wiki.py recipes  [repo-root]
    check_wiki.py skills   [repo-root]
    check_wiki.py secrets  [repo-root]
    check_wiki.py check    [repo-root]

repo-root defaults to two directories up from this script (wiki/scripts/ ->
wiki/ -> repo root).
"""
import re, sys, pathlib

CATEGORY_FILE = 'dirsAsCategory.nix'
# Same shape as modules.py's AGG -- `with config.flake.modules.<class>; [ ... ]`,
# the form every host aggregate and every dirsAsCategory.nix output uses.
AGG = re.compile(r'with\s+config\.flake\.modules\.(\w+);\s*\[(.*?)\]', re.S)
# Same shape as modules.py's DECL -- `flake.modules.<class>.<name>` (or the
# `${moduleName}` template form ellyHomeManager's per-module files use), how a
# module declares which class it belongs to.
DECL = re.compile(r'flake\.modules\.(\w+)\.(?:\$\{moduleName\}|\w+)')
COMMENT = re.compile(r'#[^\n]*')

# host short-name -> its nireHost/*-configuration.nix. lysithea is darwin-class;
# every other host is nixos-class. nire-installer and nire-llm-sandbox
# (removed 2026-08-27 and 2026-08-28 respectively -- see wiki/history.md; both
# were deliberately excluded even while they existed) are not listed here --
# CLAUDE.md's Architecture section is explicit that neither counted as "a
# host" the way these four do, and categories/README.md's "Imported by"
# columns never name either one. (nire-lego was a fifth real host here until
# its removal 2026-08-27 -- see wiki/history.md.)
HOSTS = ['durandal', 'tenacity', 'cube', 'lysithea']

IMPORTED_BY_HEADING = re.compile(r'^##\s+Imported by\s*$', re.M)
NEXT_HEADING = re.compile(r'^##\s+', re.M)


def repo_root(argv):
    if len(argv) > 1:
        return pathlib.Path(argv[1]).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def nested_category_names(categories, name):
    """`name` plus every category nested (at any depth) under its own
    directory -- e.g. `homelab` expands to itself plus `containers`,
    `git-forge`, ..., `virtualization`. Mirrors "nested categories overlap
    their parents on purpose" (flake/doc/dirsAsCategory.md): a host that
    imports the umbrella name effectively gets every module the nested ones
    do, so for the purposes of "does this host import category X" it counts
    as importing X too, even though X never appears literally in the host's
    own import list.
    """
    if name not in categories:
        return {name}
    result = {name}
    for child in categories[name].rglob(CATEGORY_FILE):
        if child.parent != categories[name]:
            result.add(child.parent.name)
    return result


def host_imports(root, categories):
    """host short-name -> set of category names it effectively imports --
    literal bare names from its own import list, expanded through any
    umbrella category among them (see nested_category_names)."""
    out = {}
    for host in HOSTS:
        p = root / 'flake' / 'modules' / 'nireHost' / f'{host}-configuration.nix'
        if not p.exists():
            print(f"WARN  expected host file missing: {p}")
            continue
        text = COMMENT.sub('', p.read_text())
        literal = set()
        for m in AGG.finditer(text):
            literal.update(re.findall(r'[\w-]+', m.group(2)))
        effective = set()
        for n in literal:
            effective |= nested_category_names(categories, n)
        out[host] = effective
    return out


def find_categories(root):
    """category name -> its directory, for every dirsAsCategory.nix under
    flake/modules/nire/ and flake/modules/nireUser/ -- the two areas
    categories/README.md actually indexes (nirePackages/* and nireHost/*
    are deliberately excluded there, see that file's own header, so this
    check has nothing to compare them against and doesn't look).
    """
    cats = {}
    for area in ('nire', 'nireUser'):
        base = root / 'flake' / 'modules' / area
        if not base.exists():
            continue
        for p in base.rglob(CATEGORY_FILE):
            cats[p.parent.name] = p.parent
    return cats


# `nire-durandal = mkHost "x86_64-linux" ...;` / `nire-lysithea = mkDarwinHost
# "aarch64-darwin" ...;` -- hosts.nix's own two attrsets, `flake.
# nixosConfigurations` and `flake.darwinConfigurations`. The constructor name
# is what tells the two apart; no need to isolate which attrset a line sits
# in first.
HOST_LINE = re.compile(r'^\s*(nire-[\w-]+)\s*=\s*(mkHost|mkDarwinHost)\b', re.M)


def actual_hosts(root):
    """host name (with `nire-` prefix, matching how wiki/hosts.md writes it)
    -> class ('nixos' or 'darwin'), read straight from hosts.nix. Deliberately
    independent of this script's own HOSTS constant (below) -- HOSTS exists
    for host_imports' narrower purpose (which per-host aggregate file to
    read) and is itself a second hand-maintained list that could in
    principle drift from hosts.nix; going back to the source here means
    check_hosts also catches that, not just wiki/hosts.md's own table.
    """
    p = root / 'flake' / 'modules' / 'nireHost' / 'hosts.nix'
    text = COMMENT.sub('', p.read_text())
    return {name: ('darwin' if ctor == 'mkDarwinHost' else 'nixos')
            for name, ctor in HOST_LINE.findall(text)}


def category_classes(category_dir):
    """The set of flake.modules.<class> declared by anything under this
    category's own directory tree, DECL-scanned rather than evaluated --
    same reasoning as scanning imports statically elsewhere in this repo's
    tooling (modules.py's own `scan`). A nested category's files live
    physically under the umbrella's tree too, so this walks straight through
    a nested `dirsAsCategory.nix` boundary rather than stopping at it: what
    the Class(es) column claims is "what importing this name actually wires
    in", and an umbrella's forClass resolves every nested name regardless of
    whether that name's own aggregate is empty for a given class (dirsAsCategory
    always defines all three, even empty -- see category-collector.nix), so
    presence of the *attribute* proves nothing; presence of an actual
    declaration under the tree does.
    """
    classes = set()
    for p in category_dir.rglob('*.nix'):
        if p.name == CATEGORY_FILE:
            continue
        # Comments stripped first: podman.nix has a commented-out
        # `flake.modules.homeManager.${moduleName}` stanza (never activated),
        # which is prose describing a possible module, not a declaration of
        # one -- left uncounted, same as scanning wiki prose that merely
        # discusses `config.flake.modules` (see modules.py's `imported_names`).
        classes.update(DECL.findall(COMMENT.sub('', p.read_text())))
    return classes


# "all four hosts" / "All three NixOS hosts" -- a page is allowed to claim
# blanket coverage in prose instead of naming every host individually. Two
# separate phrases because they cover different sets: "three NixOS hosts"
# means specifically {durandal, tenacity, cube} (lysithea is darwin,
# not NixOS), while "four hosts" means all of HOSTS including lysithea. A
# category can use the three-host phrase and still separately name lysithea
# by hand for a narrower reason (system.md, nix.md) -- so blanket coverage
# only removes hosts it actually covers from the per-host check below,
# rather than skipping that check entirely. (Before nire-lego's removal
# 2026-08-27 these were "four NixOS hosts" / "five hosts" -- renumbered,
# not renamed, since the phrases themselves are what pages actually say.)
ALL_NIXOS_HOSTS_PHRASE = re.compile(r'\ball\s+(?:three|3)\s+NixOS\s+hosts\b', re.I)
ALL_HOSTS_PHRASE = re.compile(r'\ball\s+(?:four|4)\s+hosts\b', re.I)
NIXOS_HOSTS = {'durandal', 'tenacity', 'cube'}


def _imported_by_findings(where, category, hosts, section):
    """Shared by check_imports (a page's own "## Imported by" section) and
    check_table (one cell of the Index table) -- same heuristic, same two
    finding shapes, just a different chunk of prose and a different label
    for where it came from."""
    findings = []
    covered = set()
    if ALL_NIXOS_HOSTS_PHRASE.search(section):
        covered |= NIXOS_HOSTS
    if ALL_HOSTS_PHRASE.search(section):
        covered |= set(HOSTS)

    # Hosts a blanket phrase already accounts for are satisfied; anything
    # left over (a host the blanket doesn't cover, or every host when
    # there's no blanket at all) still needs to appear by name.
    for host in hosts - covered:
        if host not in section:
            findings.append(
                f"MISSING  {where}: '{category}' is imported by "
                f"'{host}' but the host isn't named in Imported by")

    # reverse direction: a host named in the section this category's
    # actual importers don't include. Heuristic -- prose can legitimately
    # name a host to say it does NOT import the category ("not durandal").
    for host in HOSTS:
        if host in section and host not in hosts:
            findings.append(
                f"REVIEW   {where}: '{host}' is named in Imported by but "
                f"does not actually import '{category}' -- confirm this "
                f"is phrased as an exclusion, not a stale inclusion")
    return findings


def _by_category(root, categories):
    """category name -> set of host short-names that actually import it,
    nested categories already folded in via host_imports/nested_category_names.
    Shared by check_imports and check_table -- both start from the same map,
    just walk it from different directions (by category with pages, vs. by
    table row)."""
    imports = host_imports(root, categories)
    by_category = {}
    for host, names in imports.items():
        for n in names:
            by_category.setdefault(n, set()).add(host)
    return by_category


def check_imports(root):
    categories = find_categories(root)
    by_category = _by_category(root, categories)
    cat_pages_dir = root / 'wiki' / 'categories'
    findings = []

    for category, hosts in sorted(by_category.items()):
        page = cat_pages_dir / f'{category}.md'
        if not page.exists():
            continue  # no page to check this category against
        text = page.read_text()
        m = IMPORTED_BY_HEADING.search(text)
        if not m:
            findings.append(f"NO 'Imported by' SECTION  {page}")
            continue
        rest = text[m.end():]
        end = NEXT_HEADING.search(rest)
        section = rest[:end.start()] if end else rest
        findings += _imported_by_findings(page, category, hosts, section)
    return findings


INDEX_HEADING = re.compile(r'^##\s+Index\s*$', re.M)
# One Index table row: `| [name](link) | dir cell | class cell | imported-by
# cell |`. The name comes from the link TEXT, not its target -- shell-config's
# row links to `shell-config/README.md`, not `shell-config.md`, so matching
# the target would miss it.
INDEX_ROW = re.compile(
    r'^\|\s*\[(?P<name>[\w-]+)\]\([^)]*\)\s*\|(?P<dir>[^|]*)\|'
    r'(?P<cls>[^|]*)\|(?P<imp>[^|]*)\|\s*$', re.M)
BACKTICK = re.compile(r'`([^`]+)`')


def check_table(root):
    """Checks categories/README.md's "## Index" table against the tree --
    see this module's docstring for what each column can and can't be
    checked mechanically."""
    categories = find_categories(root)
    by_category = _by_category(root, categories)

    readme = root / 'wiki' / 'categories' / 'README.md'
    text = readme.read_text()
    m = INDEX_HEADING.search(text)
    if not m:
        return [f"NO 'Index' SECTION  {readme}"]
    rest = text[m.end():]
    end = NEXT_HEADING.search(rest)
    section = rest[:end.start()] if end else rest

    findings = []
    seen = set()
    for row in INDEX_ROW.finditer(section):
        name = row.group('name')
        if name not in categories:
            continue  # the header row, the separator row, or a stale link
        seen.add(name)
        cat_dir = categories[name]

        # Directory column: the first backtick span is the path itself; a
        # second one (hardware's "(+ nested `amd`)") is prose, not checked.
        expected_dir = str(cat_dir.relative_to(root / 'flake' / 'modules')) + '/'
        spans = BACKTICK.findall(row.group('dir'))
        if not spans or spans[0] != expected_dir:
            got = spans[0] if spans else '(none)'
            findings.append(
                f"DIRECTORY  {readme}: '{name}' row says {got!r}, tree has "
                f"{expected_dir!r}")

        # Class(es) column -- fully mechanical, so any mismatch is real.
        expected_classes = category_classes(cat_dir)
        claimed_classes = {c.strip() for c in row.group('cls').split(',') if c.strip()}
        if claimed_classes != expected_classes:
            findings.append(
                f"CLASSES    {readme}: '{name}' row says "
                f"{sorted(claimed_classes)}, tree declares "
                f"{sorted(expected_classes)}")

        findings += _imported_by_findings(
            f"{readme} row for '{name}'", name, by_category.get(name, set()),
            row.group('imp'))

    # A category with its own page that never made it into the table row set
    # at all -- find_categories() sees it, nothing above does without this.
    for name in sorted(categories):
        if name in seen:
            continue
        page = root / 'wiki' / 'categories' / f'{name}.md'
        if page.exists():
            findings.append(
                f"MISSING ROW  {readme}: '{name}' has {page} but no Index "
                f"table row")
    return findings


HOSTS_TABLE_ROW = re.compile(
    r'^\|\s*`(?P<host>nire-[\w-]+)`\s*\|\s*(?P<class>\w+)\s*\|'
    r'(?P<role>[^|]*)\|(?P<wipes>[^|]*)\|\s*$', re.M)


def check_hosts(root):
    """Checks wiki/hosts.md's "The hosts" table against hosts.nix and the
    `impermanence` category's actual importers -- see this module's
    docstring for what each column can and can't be checked mechanically."""
    hosts = actual_hosts(root)
    categories = find_categories(root)
    imports = host_imports(root, categories)  # short name -> category set

    page = root / 'wiki' / 'hosts.md'
    rows = {m.group('host'): m for m in HOSTS_TABLE_ROW.finditer(page.read_text())}

    findings = []
    for name in sorted(set(hosts) | set(rows)):
        if name not in rows:
            findings.append(
                f"MISSING ROW  {page}: hosts.nix declares '{name}' but The "
                f"hosts table has no row for it")
            continue
        if name not in hosts:
            findings.append(
                f"STALE ROW  {page}: '{name}' has a table row but hosts.nix "
                f"no longer declares it")
            continue
        row = rows[name]

        claimed_class = row.group('class').strip()
        if claimed_class != hosts[name]:
            findings.append(
                f"CLASS      {page}: '{name}' row says {claimed_class!r}, "
                f"hosts.nix declares it {hosts[name]!r}")

        # Wipes /root? is only meaningful for nixos-class hosts -- darwin has
        # no initrd stage this repo touches, hence hosts.md's own "n/a".
        wipes_cell = row.group('wipes').lower()
        if hosts[name] == 'darwin':
            if 'n/a' not in wipes_cell:
                findings.append(
                    f"WIPES ROOT {page}: '{name}' is darwin-class (no /root "
                    f"wipe concept) but its row doesn't say 'n/a'")
            continue
        wipes_claimed = 'yes' in wipes_cell
        wipes_actual = 'impermanence' in imports.get(name.removeprefix('nire-'), set())
        if wipes_claimed != wipes_actual:
            findings.append(
                f"WIPES ROOT {page}: '{name}' row says "
                f"{'yes' if wipes_claimed else 'no'!r}, but it "
                f"{'does' if wipes_actual else 'does not'} import "
                f"'impermanence'")
    return findings


def doc_files(root):
    """Every markdown file the three checks below scan: all of wiki/
    (recursive) plus AGENTS.md itself -- the one file outside wiki/ that
    duplicates wiki-shaped claims verbatim (CLAUDE.md is a symlink to it, so
    checking the symlink's target once covers both names)."""
    return sorted(root.joinpath('wiki').rglob('*.md')) + [root / 'AGENTS.md']


# A recipe header, e.g. `wiki-churn *args:` or `host=nire-durandal build`'s
# own definition `build:` -- name, then zero or more space-separated
# parameter/default tokens, then a bare `:`. `(?!=)` excludes a `name :=
# value` variable assignment, just's *other* use of a leading identifier.
JUST_RECIPE = re.compile(r'^([a-zA-Z][\w-]*)(?:\s+[\w=*-]+)*:(?!=)', re.M)
# A backtick-quoted invocation, e.g. `` `just wiki-lint` `` or
# `` `just host=nire-durandal build` ``.
JUST_MENTION = re.compile(r'`just ([^`]+)`')


def check_recipes(root):
    """Every backtick `just <recipe...>` mention across wiki/ and AGENTS.md
    against .justfile's own recipe names -- catches a recipe rename or
    removal silently breaking every doc that told someone to run it. Handles
    the `just host=<host> <recipe>` override form (AGENTS.md's own Commands
    section documents it) by checking the token after the `key=value`
    override, not the override itself.
    """
    justfile = root / '.justfile'
    recipes = set(JUST_RECIPE.findall(COMMENT.sub('', justfile.read_text())))

    findings = []
    for path in doc_files(root):
        for m in JUST_MENTION.finditer(path.read_text()):
            tokens = m.group(1).split()
            if not tokens or '<' in m.group(1):
                continue  # a template like `just host=<name> <recipe>`, not
                          # a literal invocation -- nothing to look up
            name = tokens[1] if '=' in tokens[0] and len(tokens) > 1 else tokens[0]
            if name not in recipes:
                findings.append(
                    f"UNKNOWN RECIPE  {path}: `just {m.group(1)}` -- "
                    f"'{name}' is not a recipe in .justfile")
    return findings


# Either word order this repo actually uses: "skill `name`" (architecture.md,
# CLAUDE.md's Traps section) or "`name` skill" (reaching-services.md). Plain
# "the `name`" is deliberately NOT matched -- most backtick tokens in this
# wiki are code identifiers, not skill names, and "skill"/"Skill" right next
# to the backticks is what actually distinguishes the two.
SKILL_MENTION = re.compile(r'[Ss]kill `([a-zA-Z][\w-]*)`|`([a-zA-Z][\w-]*)` skill\b')


def check_skills(root):
    """Every "skill `name`" / "`name` skill" mention across wiki/ and
    AGENTS.md against real `.claude/skills/<name>/` directories -- same
    shape and motivation as `recipes`, for a skill rename instead of a
    recipe rename."""
    skills_dir = root / '.claude' / 'skills'
    real = ({p.name for p in skills_dir.iterdir() if p.is_dir()}
            if skills_dir.exists() else set())

    findings = []
    for path in doc_files(root):
        for m in SKILL_MENTION.finditer(path.read_text()):
            name = m.group(1) or m.group(2)
            if name not in real:
                findings.append(
                    f"UNKNOWN SKILL  {path}: '{name}' has no "
                    f".claude/skills/{name}/ directory")
    return findings


# Both current instances end the enrolled-host list right before an em-dash;
# `re.S` lets `.*?` cross the markdown line-wrap between them.
ENROLLS_CLAIM = re.compile(r'enrolls\s+(.*?)—', re.S)
HOST_TOKEN = re.compile(r'`(nire-[\w-]+)`')


def enrolled_hosts(root):
    """host names anchored under .sops.yaml's own `keys:` list -- the actual
    enrollment, independent of the "enrolls ..." prose that names the same
    set by hand in more than one doc."""
    p = root / 'flake' / 'modules' / 'nire' / 'system' / 'secrets' / '.sops.yaml'
    return set(re.findall(r'&(nire-[\w-]+)', COMMENT.sub('', p.read_text())))


def check_secrets(root):
    """Every "`.sops.yaml` ... enrolls `host`, `host`, ... —" claim
    (wiki/impermanence-and-secrets.md and AGENTS.md's Safety section both
    make this exact claim by hand, in the same shape -- AGENTS.md's own text
    even admits "this paragraph has been stale before") against
    .sops.yaml's actual key anchors. Unlike Imported by, there's no
    legitimate named-as-an-exclusion case for enrollment, so a mismatch
    either way is a hard finding, not a REVIEW.
    """
    actual = enrolled_hosts(root)
    findings = []
    for path in doc_files(root):
        for m in ENROLLS_CLAIM.finditer(path.read_text()):
            claimed = set(HOST_TOKEN.findall(m.group(1)))
            if not claimed:
                continue  # some other "enrolls ... --" sentence, not this one
            for host in sorted(actual - claimed):
                findings.append(
                    f"MISSING  {path}: .sops.yaml enrolls '{host}' but the "
                    f"enrolls claim doesn't name it")
            for host in sorted(claimed - actual):
                findings.append(
                    f"EXTRA    {path}: the enrolls claim names '{host}' but "
                    f".sops.yaml doesn't enroll it")
    return findings


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    root = repo_root([sys.argv[0]] + sys.argv[2:])

    cmds = ('imports', 'table', 'hosts', 'recipes', 'skills', 'secrets', 'check')
    if cmd not in cmds:
        print(__doc__)
        sys.exit(2)

    findings = []
    if cmd in ('imports', 'check'):
        findings += check_imports(root)
    if cmd in ('table', 'check'):
        findings += check_table(root)
    if cmd in ('hosts', 'check'):
        findings += check_hosts(root)
    if cmd in ('recipes', 'check'):
        findings += check_recipes(root)
    if cmd in ('skills', 'check'):
        findings += check_skills(root)
    if cmd in ('secrets', 'check'):
        findings += check_secrets(root)

    for f in findings:
        print(f)
    hard = [f for f in findings if not f.startswith('REVIEW')]
    if not findings:
        print(f"{cmd}: no findings")
    elif not hard:
        print(f"{cmd}: only REVIEW findings (heuristic, needs a human look; "
              f"see this script's own docstring) -- not failing on those alone")
    sys.exit(1 if hard else 0)


if __name__ == '__main__':
    main()
