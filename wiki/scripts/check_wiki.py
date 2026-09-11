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
            prose is matched by substring. A mention governed by an
            exclusion cue in its own clause ("not durandal", "cube only
            (not the handheld)") or by an indirect-path cue ("reaches
            lysithea via `ellyHomeManager`") is NOT flagged: this wiki
            states absences deliberately, with drvPath evidence, and
            flagging all of them produced 25 permanent findings that were
            every one of them correct prose (narrowed 2026-09-11). What
            survives is a mention with no such cue nearby, which is what a
            genuinely stale inclusion looks like. Still read a finding
            before trusting it, same as `modules.py`'s own tools ask.
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
            AGENTS.md against real `.agents/skills/<name>/` directories --
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

  dates     Every page's `_Last modified: YYYY-MM-DD_` line (added
            wiki-wide 2026-09-06, right after the title and before `##
            Contents`, see styleguide.md) exists, matches that exact
            format, and isn't a future date -- the same three things a
            human proofreading it would check. It can't and doesn't check
            that the date is *current* (whether the page's content has
            actually changed since); that half is a human judgement call
            each edit makes for itself, per skill `wiki-sync`, the same
            division as `contents` catching a heading list going stale
            mechanically while deciding *what belongs* on the page stays
            manual.

  counts    The counts table in wiki/module-style-guide-for-agents.md
            (## Counts) and
            the host-count claims phrased as "all N hosts" / "all N NixOS
            hosts" / "M of the N NixOS hosts" in wiki/ + AGENTS.md, against
            recomputation: the table rows against grep over flake/modules/,
            the prose claims against hosts.nix's actual entry count (split
            by class, via the same actual_hosts the `hosts` check uses).
            Added 2026-09-09 after the style-guide's 2026-08-08 counts
            (151/70/106) and AGENTS.md's "all five hosts" both went quietly
            false -- same failure mode as `table`'s removed Members column,
            but these live in prose rather than a table the tree can't see,
            which is why they need their own subcheck.

  siblings  The `<page>.md` / `<page>-for-agents.md` pairs (styleguide.md,
            "Two audiences per page"): every sibling has a source page, every
            page over 1,000 words has a sibling unless exempt, each sibling
            is inside a 50% word budget (REVIEW only -- density is the goal,
            and a fact always beats the number), and the two link to each
            other. The real
            work is the staleness half: a sibling whose `_Last modified:_`
            predates its source's means the source was edited alone, which is
            the two-copies-one-lying failure this wiki spent its whole
            existence avoiding until the split deliberately introduced it.
            Every other duplication rule in this repo is a convention someone
            has to remember; this one is the only one worth spending a check
            on, because the split is only as good as the guard under it.
            A source edit with nothing to sync (a reorder, a typo) is landed
            with a `_Sibling reviewed: <date> -- <reason>_` line on the
            sibling, added 2026-09-11 -- the alternative on offer until then
            was bumping the sibling's date, which styleguide.md forbids for
            good reason and which this check could never have caught.

  check     Runs all thirteen of the above.

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
    check_wiki.py dates         [repo-root]
    check_wiki.py counts        [repo-root]
    check_wiki.py siblings      [repo-root]
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
import re, sys, pathlib, urllib.parse, datetime

CATEGORY_FILE = 'dirsAsCategory.nix'
# Same shape as modules.py's AGG -- `with config.flake.modules.<class>; [ ... ]`,
# the form every host aggregate and every dirsAsCategory.nix output uses.
AGG = re.compile(r'with\s+config\.flake\.modules\.(\w+);\s*\[(.*?)\]', re.S)
# Same shape as modules.py's DECL -- `flake.modules.<class>.<name>` (or the
# `${moduleName}` template form ellyHomeManager's per-module files use), how a
# module declares which class it belongs to.
DECL = re.compile(r'flake\.modules\.(\w+)\.(?:\$\{moduleName\}|\w+)')
# Declared inside a `flake.modules = { ... }` attrset, where each class
# heads its own line without the prefix -- see the call site for why this
# form exists and can't just be flattened away.
DECL_ATTRSET = re.compile(r'(?m)^\s*(\w+)\.\$\{moduleName\}\s*=')
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

# Cues that a host named in an "Imported by" section is being named to say
# it does NOT import the category, or that it gets the category by some
# other route than a direct import. Deliberately narrow: these suppress a
# REVIEW finding, so a cue that fires too easily would hide a real stale
# inclusion. "only" is NOT a cue -- it appears in "cube only", which says
# nothing about the host actually named in the same clause.
EXCLUSION_CUE = re.compile(
    r"\b(?:not|never|neither|nor|without|exclude[sd]?|excluded|absent|absence)\b",
    re.I)
# "reaches lysithea via `ellyHomeManager`" -- a true statement about a
# different mechanism, not a claim of direct import.
INDIRECT_CUE = re.compile(r"\bvia\b", re.I)

# A clause, for the purpose above: the run of prose around a mention,
# bounded by sentence/clause punctuation, a blank line, or a table-cell
# pipe. Narrower than the whole section on purpose -- "cube imports this.
# durandal does not." must not let the second sentence's "not" excuse the
# first sentence's mention, and one table cell's "not" must not excuse the
# next cell's.
#
# A BARE newline is deliberately NOT a boundary: this wiki hard-wraps
# prose, so "Confirmed not to move durandal,\ntenacity or lysithea" is one
# sentence split across lines, and treating the wrap as a clause break left
# `tenacity or lysithea` looking like an unexcused mention. That mistake
# accounted for 12 of the 25 findings this narrowing set out to remove.
_CLAUSE_SPLIT = re.compile(r'(?:[.;]\s+|\n\s*\n|\|)')


def _clauses_mentioning(section, host):
    """Every clause of `section` that names `host`."""
    return [c for c in _CLAUSE_SPLIT.split(section) if host in c]


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
        text = COMMENT.sub('', p.read_text())
        classes.update(DECL.findall(text))
        # The attrset form -- `flake.modules = { homeManager.${moduleName} = ...;
        # nixos.${moduleName} = ...; }` -- declares classes without repeating the
        # `flake.modules.` prefix. One real module is shaped this way
        # (basic-nix-settings.nix, three classes); the flat form three times in
        # one file trips statix's repeated-`flake`-key rule, so the attrset is
        # not simply expandable. Line-anchored so the leading `flake` of a flat
        # `flake.modules.<class>...` line cannot match as a class name. Missed
        # entirely by both checkers until 2026-09-08 -- the CLASSES check read
        # the nix category as homeManager-only and failed against the README's
        # correct row.
        classes.update(DECL_ATTRSET.findall(text))
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
    # actual importers don't include. Heuristic -- prose legitimately names
    # a host to say it does NOT import the category, and this repo does
    # that constantly and on purpose ("cube only (not durandal)", "Confirmed
    # not to move durandal, tenacity or lysithea" -- the drvPath evidence
    # for an exclusion is worth more than the noise it used to cost).
    #
    # So only flag a mention that ISN'T governed by an exclusion or
    # indirect-path cue in its own clause. Before this narrowing (2026-09-11)
    # every such page reported one finding per excluded host -- 25 of them,
    # all correct prose, which is exactly the volume that trains a reader to
    # skim past the one real stale inclusion.
    for host in HOSTS:
        if host not in hosts:
            for clause in _clauses_mentioning(section, host):
                if EXCLUSION_CUE.search(clause) or INDIRECT_CUE.search(clause):
                    continue
                findings.append(
                    f"REVIEW   {where}: '{host}' is named in Imported by but "
                    f"does not actually import '{category}' -- confirm this "
                    f"is phrased as an exclusion, not a stale inclusion")
                break
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
        # A category page's `-for-agents` sibling (styleguide.md, "Two
        # audiences per page") is where the import list is most useful, so
        # it may carry its own "## Imported by" -- and then BOTH copies are
        # checked, rather than the sibling's going unwatched. Only the
        # absence from both is a finding: one page of the pair may carry it
        # alone.
        sib = cat_pages_dir / f'{category}{SIBLING_SUFFIX}.md'
        checked = False
        for candidate in (page, sib):
            if not candidate.exists():
                continue
            text = candidate.read_text()
            m = IMPORTED_BY_HEADING.search(text)
            if not m:
                continue
            checked = True
            rest = text[m.end():]
            end = NEXT_HEADING.search(rest)
            section = rest[:end.start()] if end else rest
            findings += _imported_by_findings(
                candidate, category, hosts, section)
        if not checked:
            findings.append(
                f"NO 'Imported by' SECTION  {page}"
                + (f" (nor {sib})" if sib.exists() else ""))
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


# A recipe header, e.g. `wiki-churn *args:`, `host=nire-durandal build`'s
# own definition `build:`, or `opencode-attach dir='.' *args:` -- name,
# then zero or more space-separated parameter/default tokens (which may
# quote defaults), then a bare `:`. `(?!=)` excludes a `name := value`
# variable assignment, just's *other* use of a leading identifier.
# Without the quote/dot in the token class, `dir='.'` made the whole
# recipe invisible to this regex (false UNKNOWN RECIPE, hit 2026-09-08).
JUST_RECIPE = re.compile(r'^([a-zA-Z][\w-]*)(?:\s+[\w=*."\'-]+)*:(?!=)', re.M)
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
    AGENTS.md against real `.agents/skills/<name>/` directories -- same
    shape and motivation as `recipes`, for a skill rename instead of a
    recipe rename."""
    skills_dir = root / '.agents' / 'skills'
    real = ({p.name for p in skills_dir.iterdir() if p.is_dir()}
            if skills_dir.exists() else set())

    findings = []
    for path in doc_files(root):
        for m in SKILL_MENTION.finditer(path.read_text()):
            name = m.group(1) or m.group(2)
            if name not in real:
                findings.append(
                    f"UNKNOWN SKILL  {path}: '{name}' has no "
                    f".agents/skills/{name}/ directory")
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
    don't guess" reasoning lessons-learned.md §41 is about, applied statically
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
# The exact line styleguide.md requires right after a page's title:
# `_Last modified: 2026-09-06_`. Anchored to the whole line -- a stray
# trailing word or missing underscore is exactly the kind of drift this
# check exists to catch, same reasoning as CONTENTS_ITEM being just as
# strict about its own line shape.
LAST_MODIFIED_LINE = re.compile(r'^_Last modified: (\d{4}-\d{2}-\d{2})_\s*$')


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


# The `## Counts` table -- one row per convention module-style-guide.md once
# stated as an inline count. Each row is recomputed by scanning every .nix
# file under flake/modules/ with the same pattern the table's own "recompute
# by hand" line gives a reader; a row whose number doesn't match its
# recomputation is a hard finding.
#
# The table lives on the *-for-agents sibling, not on module-style-guide.md
# where it sat until 2026-09-11. Grep `STYLEGUIDE_COUNTS` finds it either
# way. It moved because it is bookkeeping, not a rule: four numbers nobody
# reads to learn the style, sitting between the human page's intro and its
# first actual convention. The sibling is where facts-to-look-up belong, and
# the check doesn't care which page it parses -- only that exactly one page
# carries the rows.
STYLEGUIDE_COUNTS = pathlib.Path('wiki/module-style-guide-for-agents.md')
MODULES_DIR = pathlib.Path('flake/modules')
COUNT_ROW = re.compile(r'^\|\s*(.+?)\s*\|\s*(\d+)\s*\|\s*$', re.M)
# The three recomputable rows, keyed by an unambiguous prefix of their label.
# `total` has no pattern -- it is the count of .nix files itself.
COUNT_DEFS = [
    ('total `.nix` files',
     None),
    ('module header',
     'moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);'),
    ('`# # description`',
     re.compile(r'(?m)^\s*# # description')),
    ('`with pkgs;`',
     'with pkgs;'),
]
# Number words a prose host-count claim can use, and the class-scoped
# variants: "all five hosts", "all 4 hosts", "all three NixOS hosts",
# "Two of the three NixOS hosts". Deliberately requires "all"/"of the" --
# historical prose ("three hosts were removed") doesn't match.
NUM = r'(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d+)'
NUMWORD = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
           'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
           'twelve': 12}
HOST_COUNT_CLAIMS = [
    # "all five hosts", "all 4 hosts" -> claim checked against the total
    (re.compile(rf'\ball ({NUM}) hosts\b', re.I), 'total'),
    # "all three NixOS hosts" -> against that class's count
    (re.compile(rf'\ball ({NUM}) (nixos|darwin) hosts\b', re.I), 'class'),
    # "Two of the three NixOS hosts" -> N against the class count; the
    # leading M is only checked for not exceeding N, since what M counts
    # (here: hosts that wipe /root) is claim-specific prose
    (re.compile(rf'\b({NUM}) of the ({NUM}) (nixos|darwin) hosts\b', re.I),
     'of-class'),
]


def _host_num(word):
    return NUMWORD.get(word.lower()) or int(word)


def check_counts(root):
    """Two shapes of count claim, both of which actually went stale here:

    - the `## Counts` table (on module-style-guide-for-agents.md, see
      STYLEGUIDE_COUNTS), one row per convention module-style-guide.md used
      to state as an inline count. Recomputed against flake/modules/ on
      every run -- the rows are a view of the tree, not a snapshot of it.
    - "all N hosts"-shaped prose across wiki/ + AGENTS.md, the exact claim
      AGENTS.md's Platform-support section got wrong ("all five hosts"
      when hosts.nix defines four). Class-scoped variants
      ("all three NixOS hosts", "Two of the three NixOS hosts") are checked
      against that class's own count.
    """
    findings = []

    text = (root / STYLEGUIDE_COUNTS).read_text()
    rows = {}
    for label, n in COUNT_ROW.findall(text):
        for key, _ in COUNT_DEFS:
            if label.startswith(key):
                rows[key] = int(n)
                break
    files = sorted((root / MODULES_DIR).rglob('*.nix'))
    for key, pattern in COUNT_DEFS:
        if key not in rows:
            continue  # a removed row is a page edit, not drift
        if pattern is None:
            actual = len(files)
        elif isinstance(pattern, re.Pattern):
            actual = sum(1 for f in files if pattern.search(f.read_text()))
        else:
            actual = sum(1 for f in files if pattern in f.read_text())
        if rows[key] != actual:
            findings.append(
                f"STALE    {root / STYLEGUIDE_COUNTS}: counts table says "
                f"{rows[key]} for '{key}' but recomputed {actual}")

    hosts = actual_hosts(root)
    class_count = {'nixos': sum(1 for c in hosts.values() if c == 'nixos'),
                   'darwin': sum(1 for c in hosts.values() if c == 'darwin')}
    for path in doc_files(root):
        text = path.read_text()
        for rx, kind in HOST_COUNT_CLAIMS:
            for m in rx.finditer(text):
                if kind == 'total':
                    claimed, actual = _host_num(m.group(1)), len(hosts)
                    if claimed != actual:
                        findings.append(
                            f"STALE    {path}: '{m.group(0)}' says "
                            f"{claimed} hosts but hosts.nix defines {actual}")
                elif kind == 'class':
                    cls = m.group(2).lower()
                    claimed, actual = _host_num(m.group(1)), class_count[cls]
                    if claimed != actual:
                        findings.append(
                            f"STALE    {path}: '{m.group(0)}' says "
                            f"{claimed} {cls} hosts but hosts.nix defines "
                            f"{actual}")
                else:
                    lead, total = _host_num(m.group(1)), _host_num(m.group(2))
                    cls = m.group(3).lower()
                    if lead > total:
                        findings.append(
                            f"STALE    {path}: '{m.group(0)}' -- {lead} "
                            f"exceeds {total}")
                    if total != class_count[cls]:
                        findings.append(
                            f"STALE    {path}: '{m.group(0)}' says {total} "
                            f"{cls} hosts but hosts.nix defines "
                            f"{class_count[cls]}")
    return findings


# The two-audience split (styleguide.md, "Two audiences per page"): a long
# wiki page is explanation for a human, and its `<page>-for-agents.md`
# sibling is the same ground compressed for something loading it mid-task.
# Deliberate duplication, against this wiki's own "index over restatement"
# rule, which is exactly why it is the one duplication in here with a
# mechanical staleness guard instead of a convention.
SIBLING_SUFFIX = '-for-agents'
# A source page at or above this many words (`wc -w`, whole file) must have
# a sibling. Below it, one is allowed but not required -- the sibling's own
# title, `_Last modified:_` line and back-link start to outweigh what
# compressing a short page saves.
SIBLING_REQUIRED_WORDS = 1000
# Word budget for a sibling, as a fraction of its source. A soft signal,
# not a rule -- over-budget is a REVIEW finding, so it never fails a run.
# The goal is information density: only what an agent needs on task, no
# narration. Where dropping the next word would drop a fact -- a page that
# is mostly irreducible commands, or an option name with a real trap
# attached -- the fact wins and the budget loses, deliberately. What this
# number is actually for is catching the other failure: a sibling quietly
# growing narrative back until it is a second copy of the page, which is
# the drift `wiki/README.md` warns about. The siblings written when this
# landed came in at 21-48% of their sources, most around 30%.
SIBLING_BUDGET = 0.50
# The escape hatch for a source edit that genuinely has nothing to sync --
# reordering a page's header, fixing a typo, rewording a sentence whose
# facts the sibling already states differently. Written on the sibling,
# under its `_Last modified:_` line:
#
#     _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
#
# It means: someone read the source as of that date and confirmed nothing
# here needs to change. A reviewed date at or after the source's date
# satisfies the staleness guard without touching this page's own
# `_Last modified:_`, which would be a lie about when the content changed.
#
# Why this exists rather than "just bump the sibling's date": styleguide.md
# tells you not to, and it is right -- a bumped date converts a caught
# omission into a silent one. But before 2026-09-11 the rule had no way to
# say "edited, nothing to sync", so the only way to land a no-op source edit
# was to do the thing the styleguide forbids. This makes the no-op case
# expressible and, more to the point, *auditable*: the claim is dated,
# attributed to a reason, and sits in the diff where a reviewer sees it.
# A reason is mandatory for exactly that -- "reviewed" with nothing after it
# is the silent bump wearing a badge.
SIBLING_REVIEWED_LINE = re.compile(
    r'^_Sibling reviewed: (\d{4}-\d{2}-\d{2})\s*(?:--|—)\s*(\S.*?)_\s*$')
# Exempt from *requiring* a sibling (each may still have one):
#   lessons-learned.md and lessons-learned/  -- already written agent-facing
#     and located by section number, not read front-to-back
#   *-history.md                             -- resolved incidents; already
#     the moved-out-of-the-way tier, rarely loaded on task
SIBLING_EXEMPT = (
    re.compile(r'^wiki/lessons-learned(\.md|/)'),
    re.compile(r'-history\.md$'),
)


def _words(text):
    """Word count matching `wc -w`, so a human can check a budget finding
    with one shell command rather than rerunning this script."""
    return len(text.split())


def _last_modified(text):
    """The page's `_Last modified:_` date, or None. check_dates is what
    reports a page missing the line at all; this just can't compare without
    it."""
    lines = text.splitlines()
    for line in lines[:6]:
        m = LAST_MODIFIED_LINE.match(line)
        if m:
            return datetime.date.fromisoformat(m.group(1))
    return None


def _sibling_reviewed(text):
    """The sibling's `_Sibling reviewed:_` date and reason, or (None, None).
    Read from the same head-of-file window as `_last_modified` so the two
    lines stay visually adjacent -- a reader hitting one sees the other."""
    for line in text.splitlines()[:8]:
        m = SIBLING_REVIEWED_LINE.match(line)
        if m:
            return datetime.date.fromisoformat(m.group(1)), m.group(2).strip()
    return None, None


def sibling_pairs(root):
    """(source_path, sibling_path) for every `<page>-for-agents.md` under
    wiki/, sibling first-class even when its source doesn't exist yet (the
    orphan case check_siblings reports)."""
    pairs = []
    for path in sorted(root.joinpath('wiki').rglob(f'*{SIBLING_SUFFIX}.md')):
        source = path.with_name(
            path.name[:-len(f'{SIBLING_SUFFIX}.md')] + '.md')
        pairs.append((source, path))
    return pairs


def check_siblings(root):
    """The `<page>.md` / `<page>-for-agents.md` pairing, four ways:

    - **orphan** -- a sibling whose source page doesn't exist (a rename that
      moved one half of the pair).
    - **missing** -- a page over SIBLING_REQUIRED_WORDS with no sibling, and
      not on the exempt list.
    - **stale** -- the guard the whole split rests on. Both pages carry
      `_Last modified:_` (checked for shape by `dates`); editing a page's
      content bumps it, per styleguide.md. So a sibling dated EARLIER than
      its source means the source was edited and the sibling wasn't, which
      is the failure mode `wiki/README.md`'s "why a link layer, not a
      rewrite" section warns about -- one fact, two copies, one of them now
      lying. Equal dates pass: that's the same-change edit the rule asks for.
      This can't tell a same-day sibling update that was actually made from
      one that was skipped after a same-day source edit -- no date check can.
      It catches the one that sat for a week, which is the one that bites.

      An older sibling is also satisfied by a `_Sibling reviewed:_` line
      dated at or after the source's (see SIBLING_REVIEWED_LINE), which is
      how a source edit with genuinely nothing to sync gets landed without
      either lying about the sibling's own modification date or leaving the
      run red. The reason is mandatory and the date can't be in the future --
      a forged future date would silence this pair permanently.
    - **budget** -- a sibling over SIBLING_BUDGET of its source's words.
      REVIEW only: the point of a sibling is information density, and a
      page that is mostly commands has a floor no amount of editing gets
      under. Losing a fact to hit a number is the worse outcome.

    Plus both back-links: the source names its sibling so a human lands on
    the dense version when they want it, and the sibling names its source so
    an agent that needs the reasoning knows where it went."""
    findings = []
    have_sibling = set()

    for source, sib in sibling_pairs(root):
        rel_sib = sib.relative_to(root).as_posix()
        rel_src = source.relative_to(root).as_posix()
        if not source.exists():
            findings.append(
                f"ORPHAN SIBLING  {rel_sib}: no {rel_src} for it to condense")
            continue
        have_sibling.add(source)
        src_text, sib_text = source.read_text(), sib.read_text()

        src_date, sib_date = _last_modified(src_text), _last_modified(sib_text)
        rev_date, rev_reason = _sibling_reviewed(sib_text)
        if rev_date and rev_date > datetime.date.today():
            findings.append(
                f"FUTURE REVIEW  {rel_sib}: Sibling reviewed says {rev_date}, "
                f"which is after today ({datetime.date.today()}) -- a future "
                f"date would satisfy this pair's staleness guard forever")
            rev_date = None
        if src_date and sib_date and sib_date < src_date:
            if rev_date and rev_date >= src_date:
                pass  # declared no-op: read as of rev_date, nothing to sync
            elif rev_date:
                findings.append(
                    f"STALE SIBLING  {rel_sib}: Sibling reviewed {rev_date} "
                    f"({rev_reason}) predates {rel_src}'s {src_date} -- that "
                    f"page has been edited again since the review; re-read it "
                    f"and either follow the edit here or re-date the review")
            else:
                findings.append(
                    f"STALE SIBLING  {rel_sib}: Last modified {sib_date} is "
                    f"older than {rel_src}'s {src_date} -- that page was "
                    f"edited without its condensed sibling following in the "
                    f"same change. If the edit genuinely had nothing to sync, "
                    f"say so with a `_Sibling reviewed: {src_date} -- "
                    f"<reason>_` line here rather than bumping the date above")

        src_words, sib_words = _words(src_text), _words(sib_text)
        budget = int(src_words * SIBLING_BUDGET)
        if sib_words > budget:
            findings.append(
                f"REVIEW   {rel_sib}: {sib_words} words against a "
                f"{budget}-word budget ({int(SIBLING_BUDGET * 100)}% of "
                f"{rel_src}'s {src_words}) -- cut narration, not facts; if "
                f"what's left is all load-bearing, over is the right answer")

        if sib.name not in src_text:
            findings.append(
                f"NO SIBLING LINK  {rel_src}: doesn't link to {sib.name}")
        if source.name not in sib_text:
            findings.append(
                f"NO SOURCE LINK  {rel_sib}: doesn't link back to "
                f"{source.name}")

    for path in sorted(root.joinpath('wiki').rglob('*.md')):
        rel = path.relative_to(root).as_posix()
        if path.name.endswith(f'{SIBLING_SUFFIX}.md') or path in have_sibling:
            continue
        if any(rx.search(rel) for rx in SIBLING_EXEMPT):
            continue
        words = _words(path.read_text())
        if words >= SIBLING_REQUIRED_WORDS:
            findings.append(
                f"MISSING SIBLING  {rel}: {words} words, over the "
                f"{SIBLING_REQUIRED_WORDS}-word line, but has no "
                f"{path.stem}{SIBLING_SUFFIX}.md")
    return findings


def check_dates(root):
    """Every page under wiki/ has a `_Last modified: YYYY-MM-DD_` line right
    after its title, in exactly the format styleguide.md's Content-shape
    section specifies, and that date isn't in the future. This is the
    presence-and-shape half of the convention -- extractable and mechanical,
    same as `contents`. It is NOT a claim that the date is still accurate:
    telling whether a page's *content* has moved on since that date needs a
    human reading the diff, which is what skill `wiki-sync` is for. A page
    whose only heading is the title itself (none currently exist) still
    needs the line -- there's no exemption for a short page."""
    findings = []
    today = datetime.date.today()
    for path in sorted(root.joinpath('wiki').rglob('*.md')):
        lines = path.read_text().splitlines()
        if not lines or not lines[0].startswith('# '):
            continue  # no title line to anchor the check against
        i = 1
        while i < len(lines) and lines[i].strip() == '':
            i += 1
        m = LAST_MODIFIED_LINE.match(lines[i]) if i < len(lines) else None
        if not m:
            findings.append(
                f"MISSING LAST-MODIFIED  {path}: no `_Last modified: "
                f"YYYY-MM-DD_` line right after the title")
            continue
        date = datetime.date.fromisoformat(m.group(1))
        if date > today:
            findings.append(
                f"FUTURE DATE  {path}: Last modified says {date}, which is "
                f"after today ({today})")
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
    separate from the check itself.

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
        # A `_Last modified: ..._` line (styleguide.md) sits between the
        # title and Contents -- skip past it too, so a fresh Contents block
        # lands after it rather than splitting title from date.
        if insert_at < len(lines) and LAST_MODIFIED_LINE.match(lines[insert_at]):
            insert_at += 1
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
            'routes', 'links', 'anchors', 'contents', 'dates', 'counts',
            'siblings', 'check')
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
    if cmd in ('dates', 'check'):
        findings += check_dates(root)
    if cmd in ('counts', 'check'):
        findings += check_counts(root)
    if cmd in ('siblings', 'check'):
        findings += check_siblings(root)

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
