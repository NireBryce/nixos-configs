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

  routes    Every routed URL mentioned in wiki/ or AGENTS.md (the tailnet
            FQDN form, or the `.../name/` shorthand) against caddy.nix's
            actual path prefixes, read out of its embedded Caddyfile string.
            Narrower than the others: it only catches a route renamed or
            removed out from under a doc that still names the old prefix,
            not which of `handle`/`handle_path` a doc claims -- that nuance
            is phrased too many different ways to match reliably. Cube-only,
            one file, so no per-host or per-category generality needed.

  links     Every relative markdown link (`[text](target)`) across wiki/ and
            AGENTS.md resolves to a real file, percent-decoded first so
            `claude%20cave/...` is checked as the real path it is rather
            than the literal encoded string. Unlike every other check here,
            this one is fully general instead of scanning for one specific
            claim shape -- a link target is unambiguously either a real path
            or not, no historical-prose judgement call needed. See
            `wiki/scripts/wiki_stale_refs.py` for the bare-filename mention
            (no link, just a name in backticks) version of this same idea,
            which DOES need that judgement call and so is a separate,
            report-only, never-fails tool rather than a subcommand here --
            same reasoning as `wiki_churn.py` living outside this file.

  anchors   Every `#fragment` on a markdown link -- same-file (`(#see-also)`)
            or into another page (`reverse-proxy.md#the-two-apps-...`) --
            against a real GitHub-slug computation of the target page's own
            headings (`github_slug`, reverse-engineered against real
            rendered output from this repo's own GitHub pages, not assumed).
            `check_links` above deliberately only checks the file half of a
            link and says so in its own docstring; this is the fragment
            half, added 2026-09-01 after a hand-derived anchor
            (`categories/homelab.md`'s link into `virtualization.md`'s
            `VMs/_lib/...` heading) turned out wrong and sat that way
            unnoticed, since nothing checked it.

  contents  Every page's `## Contents` block (added wiki-wide 2026-09-01,
            one per page, see styleguide.md) against what its own `##`
            headings say right now -- catches a heading renamed, added, or
            removed without the list above it following along. Skips a page
            with no `## Contents` section rather than demanding one; that
            expectation lives in styleguide.md, not here.

  check     Runs all ten of the above.

    check_wiki.py imports       [repo-root]
    check_wiki.py table         [repo-root]
    check_wiki.py hosts         [repo-root]
    check_wiki.py recipes       [repo-root]
    check_wiki.py skills        [repo-root]
    check_wiki.py secrets       [repo-root]
    check_wiki.py routes        [repo-root]
    check_wiki.py links         [repo-root]
    check_wiki.py anchors       [repo-root]
    check_wiki.py contents      [repo-root]
    check_wiki.py check         [repo-root]
    check_wiki.py gen-contents  <file.md> [file.md ...]

repo-root defaults to two directories up from this script (wiki/scripts/ ->
wiki/ -> repo root). `gen-contents` is different in kind from every command
above -- a fixer, not a checker, so it takes file paths instead and is not
part of `check`'s aggregate: it rewrites each given page's `## Contents`
block in place to match that page's real headings, which is the actual fix
for a `contents` finding (and, if the broken link was into the page's own
Contents list rather than someone else's, an `anchors` finding too).
"""
import re, sys, pathlib, urllib.parse

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


CADDY_NIX = pathlib.Path('flake/modules/nire/homelab/reverse-proxy/caddy/caddy.nix')
# `@grafana path /grafana /grafana/*` then plain `handle` -- Grafana serves
# UNDER the prefix (serve_from_sub_path) and needs it left on. The `\1`
# backreference is what `caddy adapt` itself would reject a mismatched pair
# as (see caddy.nix's own header on the two-path form).
CADDY_KEPT_PATH = re.compile(r'path\s+/([\w-]+)\s+/\1/\*')
# `handle_path /git/*` -- Forgejo has no serve_from_sub_path equivalent and
# always serves at `/`, so the prefix has to be stripped before reaching it.
CADDY_STRIPPED_PATH = re.compile(r'handle_path\s+/([\w-]+)/\*')
# The two forms this wiki actually writes a routed URL in: the full FQDN
# (reaching-services.md, categories/monitoring.md) or the `.../name/`
# shorthand (homelab/README.md) -- deliberately NOT a bare `/name/` pattern,
# which would also match ordinary filesystem paths like `/root/` or
# `/persist/` that have nothing to do with Caddy.
ROUTE_MENTION = re.compile(r'ts-cube\.moose-micro\.ts\.net/([\w-]+)/|`\.\.\./([\w-]+)/`')


def caddy_routes(root):
    """path-prefix name -> True if Caddy strips it before reaching the app,
    False if it's kept -- read straight out of caddy.nix's own embedded
    Caddyfile string rather than assumed (the "read the built artifact,
    don't guess" reasoning lessons-learned #41 is about, applied statically
    here instead of via `caddy adapt`). Cube-only and there's exactly one
    caddy.nix, so no need for find_categories-style generality."""
    p = root / CADDY_NIX
    if not p.exists():
        return {}
    text = p.read_text()
    routes = {name: False for name in CADDY_KEPT_PATH.findall(text)}
    routes.update({name: True for name in CADDY_STRIPPED_PATH.findall(text)})
    return routes


def check_routes(root):
    """Every routed URL mentioned in wiki/ or AGENTS.md (the two shapes this
    wiki actually uses -- see ROUTE_MENTION) against caddy.nix's real path
    prefixes. Narrower than the other checks: it only catches a route that's
    been renamed or removed in caddy.nix out from under a doc that still
    names the old prefix, not which of `handle`/`handle_path` a doc claims --
    that nuance shows up in enough different phrasings that matching it
    reliably would cost more false positives than it's worth.
    """
    routes = caddy_routes(root)
    findings = []
    for path in doc_files(root):
        for m in ROUTE_MENTION.finditer(path.read_text()):
            name = m.group(1) or m.group(2)
            if name not in routes:
                findings.append(
                    f"UNKNOWN ROUTE  {path}: '/{name}/' is mentioned but "
                    f"caddy.nix has no matching route")
    return findings


# `[text](target)` -- the target only; `text` isn't checked against anything.
MD_LINK = re.compile(r'\[[^\]]*\]\(([^)]+)\)')


def check_links(root):
    """Every relative markdown link across wiki/ and AGENTS.md resolves to a
    real file. Skips `http(s)://`/`mailto:` targets (nothing on disk to
    check) and a pure in-page anchor (`(#see-also)`, no file component).
    Percent-decodes the target first -- `claude%20cave/...` is a real,
    existing path (the directory has a literal space in its name); comparing
    the raw encoded string against the filesystem is what would make this
    check wrong about a link that actually works.

    Unlike the other checks here, this one is fully general rather than
    scanning for one specific claim shape -- a link target is unambiguously
    either a real path or not, no historical-prose judgement call needed
    (contrast the bare-filename mentions `wiki/scripts/wiki_stale_refs.py`
    reports instead, which need exactly that judgement call and so are
    heuristic and report-only rather than a hard check here).
    """
    findings = []
    for path in doc_files(root):
        for m in MD_LINK.finditer(path.read_text()):
            target = m.group(1).strip()
            if target.startswith(('http://', 'https://', 'mailto:')):
                continue
            file_part = urllib.parse.unquote(target.split('#', 1)[0].strip('<>'))
            if not file_part:
                continue  # pure in-page anchor, e.g. (#see-also)
            resolved = path.parent / file_part
            if not resolved.exists():
                findings.append(
                    f"BROKEN LINK  {path}: ({target}) -> {resolved} does "
                    f"not exist")
    return findings


FENCE = re.compile(r'^(```|~~~)')
HEADING = re.compile(r'^(#{1,6})\s+(.+?)\s*$')
CONTENTS_HEADING = re.compile(r'^##\s+Contents\s*$', re.M)
CONTENTS_ITEM = re.compile(r'^-\s+\[(?P<text>.+)\]\(#(?P<slug>[^)]+)\)\s*$', re.M)


def _iter_headings(text):
    """Yields (level, raw_heading_text) for every real heading line -- `#`
    through `######` -- in document order, skipping anything inside a fenced
    code block (```` ``` ```` or `~~~`). Without the fence tracking, a shell
    comment like `# or, one-off:` inside a ```sh block (`homelab/rustic.md`
    has exactly this) would be misread as a level-1 heading."""
    in_fence = False
    for line in text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        m = HEADING.match(line)
        if m:
            yield len(m.group(1)), m.group(2)


def github_slug(raw, seen):
    """GitHub's own heading-anchor algorithm -- reverse-engineered against
    real rendered output (fetched 2026-09-01 from this repo's own pages on
    github.com, after a hand-derived anchor turned out wrong -- see
    `wiki/styleguide.md`'s Content-shape section) rather than assumed:
    lowercase, drop every character that isn't a letter/digit/space/hyphen/
    underscore -- backticks, colons, periods, em-dashes, quotes, slashes,
    asterisks all just disappear, nothing put in their place, so a removed
    character sitting between two spaces leaves a double hyphen once spaces
    become hyphens, and one with no surrounding space glues its two
    neighbors together with none (`` `VMs/_lib/libvirt-vm.nix` `` slugs to
    `vms_liblibvirt-vmnix`, confirmed against the live page, not the
    `vmslib-libvirt-vmnix` a previous session guessed and left linked from
    `categories/homelab.md`) -- then turn each remaining space into a
    hyphen. `seen` is a dict this function mutates so repeated headings on
    one page get GitHub's own `-1`/`-2` suffix instead of colliding; pass a
    fresh `{}` per page, not per heading, and feed it every heading in
    document order (including ones you don't otherwise care about) so the
    counters land where GitHub's would.

    Known gap: operates on the heading's raw source characters, not a
    markdown-aware plain-text extraction -- a heading containing an actual
    `[text](url)` link (none currently exist in this wiki) would slug
    wrong, since the URL's characters aren't stripped as a unit. Backticks,
    `**bold**`, and `*italic*` are fine, since stripping their marker
    characters one at a time happens to produce the same result GitHub's
    real markdown-aware slugger gives."""
    s = raw.lower()
    s = ''.join(c for c in s if c.isalnum() or c in ' -_')
    s = s.replace(' ', '-')
    n = seen.get(s, 0)
    seen[s] = n + 1
    return s if n == 0 else f'{s}-{n}'


def _page_anchors(path):
    """Every heading anchor a real GitHub render of `path` would produce, as
    a set of slugs."""
    seen = {}
    return {github_slug(text, seen) for _, text in _iter_headings(path.read_text())}


def check_anchors(root):
    """Every `#fragment` on a markdown link -- same-file (`(#see-also)`) or
    into another page (`reverse-proxy.md#the-two-apps-...`) -- resolves to a
    real heading on the target page, per `github_slug` above. This is the
    check `check_links` explicitly does NOT do (its own docstring only
    checks the file half of a link), which is what let the wrong
    `vmslib-libvirt-vmnix` anchor above sit unnoticed. Skips a target
    `check_links` would already flag as a broken file path -- nothing to
    check the fragment against, and no point duplicating that finding."""
    cache = {}
    findings = []
    for path in doc_files(root):
        for m in MD_LINK.finditer(path.read_text()):
            target = m.group(1).strip()
            if target.startswith(('http://', 'https://', 'mailto:')):
                continue
            if '#' not in target:
                continue
            file_part, _, frag = target.partition('#')
            file_part = urllib.parse.unquote(file_part.strip('<>'))
            frag = urllib.parse.unquote(frag)
            if not frag:
                continue  # a bare (#) with nothing after it -- not real
            resolved = (path.parent / file_part) if file_part else path
            if not resolved.exists():
                continue  # check_links already reports this
            if resolved not in cache:
                cache[resolved] = _page_anchors(resolved)
            if frag not in cache[resolved]:
                findings.append(
                    f"BROKEN ANCHOR  {path}: ({target}) -> {resolved} has no "
                    f"heading matching #{frag}")
    return findings


def expected_contents_items(text):
    """[(heading_text, slug), ...] a fresh `## Contents` block for this page
    should list, in document order -- level-2 headings only, excluding a
    heading literally named `Contents` (itself). Slugs every heading on the
    page, not just the level-2 ones, so GitHub's per-page dedup counter
    lands on the right ones even though only level-2 headings make it into
    the returned list -- see `wiki/styleguide.md`'s Content-shape section
    for why Contents is H2-only (several pages nest `###` steps under one H2
    and Contents stays a flat top-level list, not a full outline)."""
    seen = {}
    items = []
    for level, text_ in _iter_headings(text):
        slug = github_slug(text_, seen)
        if level == 2 and text_.strip() != 'Contents':
            items.append((text_, slug))
    return items


def actual_contents_items(text):
    """[(heading_text, slug), ...] a page's existing `## Contents` block
    actually lists, read back from the file rather than assumed -- or
    `None` if the page has no such section at all."""
    m = CONTENTS_HEADING.search(text)
    if not m:
        return None
    rest = text[m.end():]
    end = NEXT_HEADING.search(rest)
    section = rest[:end.start()] if end else rest
    return [(mm.group('text'), mm.group('slug'))
            for mm in CONTENTS_ITEM.finditer(section)]


def check_contents(root):
    """Every page's `## Contents` block matches what `expected_contents_items`
    would generate from its own headings right now -- catches the drift this
    whole mechanism exists to prevent: a heading renamed, added, or removed
    without updating the list above it. Skips a page with no `## Contents`
    section (nothing to check against) rather than demanding every page have
    one; `styleguide.md` is where that expectation is written down instead."""
    findings = []
    for path in sorted(root.joinpath('wiki').rglob('*.md')):
        text = path.read_text()
        actual = actual_contents_items(text)
        if actual is None:
            continue
        if actual != expected_contents_items(text):
            findings.append(
                f"STALE CONTENTS  {path}: its '## Contents' list doesn't "
                f"match its own headings -- fix with `gen-contents {path}`")
    return findings


CONTENTS_ITEM_LINE = re.compile(r'^-\s+\[.+\]\(#[^)]+\)\s*$')


def regenerate_contents(path):
    """Rewrites `path`'s `## Contents` block in place to match its current
    headings exactly -- inserting one right after the title if the page
    doesn't have one yet. Idempotent: safe to run any time after adding,
    renaming, or removing a heading. This is the actual fix for every
    `STALE CONTENTS` finding above, and for a `BROKEN ANCHOR` finding whose
    link points at the page's own Contents block rather than someone else's
    -- not run automatically by `check`, since it writes files rather than
    reporting, the same reasoning that keeps `--fix` flows in this repo
    (`code-review`, `simplify`) separate from the check itself.

    Replaces ONLY the contiguous run of `- [text](#slug)` lines right after
    the `## Contents` heading -- never "everything up to the next `##`
    heading" the way `check_table`'s NEXT_HEADING trick does elsewhere in
    this file. Several pages put a line or two of intro prose between the
    Contents heading and the first real section (deliberately -- title,
    Contents, intro, first heading); an earlier version of this function
    used the NEXT_HEADING span and silently deleted that prose on every
    such page the first time it ran. Bullet-list-only replacement can't
    repeat that mistake no matter what sits after the list."""
    text = path.read_text()
    items = expected_contents_items(text)
    block = '## Contents\n\n' + '\n'.join(f'- [{t}](#{s})' for t, s in items) + '\n'
    m = CONTENTS_HEADING.search(text)
    if m:
        rest = text[m.end():]
        lines = rest.splitlines(keepends=True)
        i = 0
        while i < len(lines) and lines[i].strip() == '':
            i += 1
        while i < len(lines) and CONTENTS_ITEM_LINE.match(lines[i]):
            i += 1
        tail = m.end() + sum(len(l) for l in lines[:i])
        new_text = text[:m.start()] + block + text[tail:]
    else:
        lines = text.splitlines(keepends=True)
        if not lines or not lines[0].startswith('# '):
            print(f"SKIP {path}: no '# Title' line to insert Contents after")
            return
        insert_at = 1
        while insert_at < len(lines) and lines[insert_at].strip() == '':
            insert_at += 1
        new_text = ''.join(lines[:insert_at]) + block + '\n' + ''.join(lines[insert_at:])
    if new_text != text:
        path.write_text(new_text)
        print(f"updated {path}")
    else:
        print(f"unchanged {path}")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'gen-contents':
        if len(sys.argv) < 3:
            print("usage: check_wiki.py gen-contents <file.md> [file.md ...]")
            sys.exit(2)
        for p in sys.argv[2:]:
            regenerate_contents(pathlib.Path(p))
        sys.exit(0)

    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    root = repo_root([sys.argv[0]] + sys.argv[2:])

    cmds = ('imports', 'table', 'hosts', 'recipes', 'skills', 'secrets',
            'routes', 'links', 'anchors', 'contents', 'check')
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
    if cmd in ('routes', 'check'):
        findings += check_routes(root)
    if cmd in ('links', 'check'):
        findings += check_links(root)
    if cmd in ('anchors', 'check'):
        findings += check_anchors(root)
    if cmd in ('contents', 'check'):
        findings += check_contents(root)

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
