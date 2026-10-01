#!/usr/bin/env python3
"""Static checks of wiki/ (and AGENTS.md plus `.agents/rules/*.md`, the files
outside wiki/ that duplicate wiki-shaped claims verbatim -- see `doc_files`)
against the actual
module tree, for authoritative claims that silently go stale after a
refactor -- a category moved, a host stopped importing something, a recipe
got renamed. Same motivation as `flake/scripts/modules.py`: nothing about
`nix flake check` or `just modules` reads prose, so a doc can say something
the repo has stopped agreeing with and nothing catches it.

This does NOT replace human judgement about whether a change actually needs a
wiki update -- see skill `wiki-sync` for that. It only catches the mechanical
case: a claim that's phrased as a checkable fact (an import list, a path) and
no longer matches what's on disk. Historical claims ("added 2026-08-21 as
`system/foo/`") are deliberately NOT the target -- this repo keeps those on
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
            Categories with no wiki page (packages-config/* subcategories,
            host-config/* bundles -- see categories/00-INDEX.md's own exclusion
            list) are silently skipped: nothing to check them against.

  table     The Imported by column of categories/00-INDEX.md's "## Index"
            tables, with the same substring/blanket-phrase heuristic as
            `imports` above, applied to the table cell instead of a page's
            own section. Narrowed 2026-10-01: the Category, Directory and
            Class(es) columns (and which categories get a row at all) are
            generated now -- wiki_gen.py, checked by `generated` below --
            so only the hand-written column is left to check here. (A
            per-category file COUNT "Members" column used to live in this
            table too; removed 2026-08-29 once hand-incrementing it on every
            module add/remove outweighed what it told a reader.)

  generated The tables wiki_gen.py generates (wiki/hosts.md's host table,
            categories/00-INDEX.md's two Index tables, module-style-guide-
            for-agents.md's counts) against a fresh render: a stale region,
            a missing or unknown one, or an empty hand-written cell is a
            hard finding. Same check as `just wiki-gen --check`; the fix is
            `just wiki-gen`, never a hand edit inside the region. Replaced
            the `hosts` check (Class / Wipes `/root`? / Tailnet name vs
            hosts.nix, retired 2026-10-01) and the table half of `counts`.

  recipes   Every backtick `just <recipe...>` mention across wiki/ and
            AGENTS.md against .justfile's own recipe names -- a rename or
            removal silently breaks every doc that told someone to run the
            old name, and nothing about `just` itself would complain until
            someone actually tried it.

  skills    Every "skill `name`"/"`name` skill" mention across wiki/ and
            AGENTS.md against real `.agents/skills/<name>/` directories --
            same shape as `recipes`, for a skill rename instead.

  skill-files
            The `.agents/skills/**/*.md` files themselves, turned inward --
            skill prose is re-read even less than wiki/ (loaded on trigger,
            written once) and rots the same way, so the same lookups apply
            to it: `just <recipe>` mentions (backticked anywhere, bare
            inside fenced code blocks -- a raw-text scan would drown in
            prose like "just say what you're doing", so prose is
            deliberately not scanned) against .justfile, the same lookup
            `recipes` does; "skill `name`"/"`name` skill" mentions against
            real skill directories, the same lookup `skills` does for wiki/
            and AGENTS.md; every relative markdown link resolving to a real
            file, the same lookup `links` does; and every repo-rooted
            backtick path (wiki/, flake/, .agents/, .github/, scripts/) --
            prefix-scoped because prefix-less names like `hosts.nix` are
            prose shorthand this repo writes several ways, the judgement
            call `wiki_stale_refs.py` exists for. Plus the two things only
            a SKILL.md has: frontmatter `name` matching its directory, and
            a `description` keeping the shape skill `new-skill` specifies
            (one sentence, no repo paths, no parentheticals -- hard
            findings; wordiness is REVIEW only, density is a human call
            the way it is for siblings). The optional `when_to_use` (Claude
            Code appends it to the description in the skill listing) must
            be one line, carry no repo path, and keep description +
            when_to_use under the listing's 1,536-char cap; over 40 words
            is REVIEW. Frontmatter keys outside name/description/
            when_to_use are findings (a misspelt key is silently ignored),
            and both values must be plain YAML scalars -- a leading quote
            or an embedded ': ' reads fine to these regexes but breaks the
            harness's YAML parse.

  secrets   The "`.sops.yaml` ... enrolls `host`, `host`, ... —" claim
            (wiki/impermanence-and-secrets.md and .agents/rules/secrets.md
            both make it, in the same shape) against .sops.yaml's
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

  counts    The host-count claims phrased as "all N hosts" / "all N NixOS
            hosts" / "M of the N NixOS hosts" in wiki/ + AGENTS.md, against
            hosts.nix's actual entry count (split by class, via
            actual_hosts). Added 2026-09-09 after AGENTS.md's "all five
            hosts" went quietly false. Its other half, the counts table on
            module-style-guide-for-agents.md, is generated since 2026-10-01
            (`generated` above) -- prose counts can't be, so they stay here.

  siblings  The `<page>.md` / `<page>-for-agents.md` pairs (styleguide.md,
            "Two audiences per page"): every sibling has a source page, every
            page over 1,000 words has a sibling or opens with `## Quick
            facts` (the folded shape, since 2026-10-01) unless exempt, each sibling
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

  lessons   wiki/lessons-learned.md is an index, one `- **§N** [title](...)
            — rule. Home: ... Enforced: ...` entry per lesson, grouped by
            when it applies (reorganised 2026-09-29 from an era-ordered page
            whose header had drifted eleven lessons behind its entries).
            Checks: every § from 1 to the highest has exactly one entry and
            exactly one `wiki/lessons-learned/<N>-*.md` article whose title
            reads `# N.`; each entry links its own article and carries both
            `Home:` and `Enforced:`. The fields' contents are validated by
            the checks that already read backticked recipe and skill names
            and relative links; this one only guarantees they exist, so an
            entry can't land without saying where its rule lives.

  rules     The path-scoped rule files, `.agents/rules/*.md` (Claude Code
            reads them as `.claude/rules/` and loads each only when a file
            matching its `paths:` frontmatter is read). Each must open with
            frontmatter whose only key is `paths:` (the only field Claude
            Code reads; anything else is silently ignored), as a non-empty
            YAML list of quoted globs; every glob must match at least one
            git-tracked file, since a glob that matches nothing means the
            rule never loads and nothing says so; and AGENTS.md must name
            the file (`.agents/rules/<name>.md`), the pointer harnesses
            without rule support depend on. The rules' prose is already in
            `doc_files`, so recipes, skills, links, secrets and counts cover
            it.

  check     Runs all sixteen of the above.

    check_wiki.py imports       [repo-root]
    check_wiki.py table         [repo-root]
    check_wiki.py recipes       [repo-root]
    check_wiki.py skills        [repo-root]
    check_wiki.py skill-files   [repo-root]
    check_wiki.py secrets       [repo-root]
    check_wiki.py routes        [repo-root]
    check_wiki.py links         [repo-root]
    check_wiki.py anchors       [repo-root]
    check_wiki.py contents      [repo-root]
    check_wiki.py dates         [repo-root]
    check_wiki.py counts        [repo-root]
    check_wiki.py generated     [repo-root]
    check_wiki.py siblings      [repo-root]
    check_wiki.py lessons       [repo-root]
    check_wiki.py rules         [repo-root]
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

# Category shims are found by what they import, not by filename -- same as
# flake/scripts/modules.py and the collector itself, so renaming every shim
# needs no change here.
SHIM = re.compile(r'import\s*\(.*"/_lib/category-collector\.nix"\)')


def is_shim(path):
    return bool(SHIM.search(re.sub(r'#[^\n]*', '', path.read_text())))


def shims_under(base):
    """Every category shim under `base`, skipping `_` paths the way
    import-tree does."""
    return [p for p in base.rglob('*.nix')
            if not any(part.startswith('_') for part in p.relative_to(base).parts)
            and is_shim(p)]
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

# host short-name -> its host-config/*-configuration.nix. lysithea is darwin-class;
# every other host is nixos-class. nire-installer and nire-llm-sandbox
# (removed 2026-08-27 and 2026-08-28 respectively -- see wiki/history.md; both
# were deliberately excluded even while they existed) are not listed here --
# CLAUDE.md's Architecture section is explicit that neither counted as "a
# host" the way these four do, and categories/00-INDEX.md's "Imported by"
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
    for child in shims_under(categories[name]):
        if child.parent != categories[name]:
            result.add(child.parent.name)
    return result


def host_imports(root, categories, hosts=None):
    """host short-name -> set of category names it effectively imports --
    literal bare names from its own import list, expanded through any
    umbrella category among them (see nested_category_names). `hosts`
    defaults to HOSTS; wiki_gen.py passes hosts.nix's own roster instead,
    so a host missing from HOSTS still gets its row computed."""
    out = {}
    for host in (HOSTS if hosts is None else hosts):
        p = root / 'flake' / 'modules' / 'host-config' / f'{host}-configuration.nix'
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
    flake/modules/general-config/ and flake/modules/users-config/ -- the two areas
    categories/00-INDEX.md actually indexes (packages-config/* and host-config/*
    are deliberately excluded there, see that file's own header, so this
    check has nothing to compare them against and doesn't look).
    """
    cats = {}
    for area in ('general-config', 'users-config'):
        base = root / 'flake' / 'modules' / area
        if not base.exists():
            continue
        for p in shims_under(base):
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
    principle drift from hosts.nix; wiki_gen.py renders hosts.md's table
    from this, not from HOSTS, so a host missing there still gets a row.
    """
    p = root / 'flake' / 'modules' / 'host-config' / 'hosts.nix'
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
        if is_shim(p):
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
        # the nix category as homeManager-only and failed against the
        # 00-INDEX's correct row.
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
# row links to `shell-config/00-INDEX.md`, not `shell-config.md`, so matching
# the target would miss it.
INDEX_ROW = re.compile(
    r'^\|\s*\[(?P<name>[\w-]+)\]\([^)]*\)\s*\|(?P<dir>[^|]*)\|'
    r'(?P<cls>[^|]*)\|(?P<imp>[^|]*)\|\s*$', re.M)
BACKTICK = re.compile(r'`([^`]+)`')


def check_table(root):
    """The Imported by cells of categories/00-INDEX.md's "## Index" tables --
    the one hand-written column there; the rest is wiki_gen.py's (see this
    module's docstring)."""
    categories = find_categories(root)
    by_category = _by_category(root, categories)

    index_page = root / 'wiki' / 'categories' / '00-INDEX.md'
    text = index_page.read_text()
    m = INDEX_HEADING.search(text)
    if not m:
        return [f"NO 'Index' SECTION  {index_page}"]
    rest = text[m.end():]
    end = NEXT_HEADING.search(rest)
    section = rest[:end.start()] if end else rest

    findings = []
    for row in INDEX_ROW.finditer(section):
        name = row.group('name')
        if name not in categories:
            continue  # the header row or the separator row
        findings += _imported_by_findings(
            f"{index_page} row for '{name}'", name, by_category.get(name, set()),
            row.group('imp'))
    return findings


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
    subdirectories too. `.claude` is a symlink to `.agents`, so this is the
    one real copy."""
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


# A recipe header, e.g. `wiki-churn *args:`, `host=nire-durandal build`'s
# own definition `build:`, or `opencode-attach dir='.' *args:` -- name,
# then zero or more space-separated parameter/default tokens (which may
# quote defaults), then a bare `:`. `(?!=)` excludes a `name := value`
# variable assignment, just's *other* use of a leading identifier.
# Without the quote/dot in the token class, `dir='.'` made the whole
# recipe invisible to this regex (false UNKNOWN RECIPE, hit 2026-09-08).
JUST_RECIPE = re.compile(r'^([a-zA-Z][\w-]*)(?:\s+[\w=*."\'-]+)*:(?!=)', re.M)
# A just module declaration, e.g. `mod agent '.agents/scripts/agent.just'`
# (optionally `mod?`). `just agent` / `just agent <recipe>` dispatch through
# it, so the module name counts as a recipe for mention-checking; its own
# recipes aren't looked up (added 2026-09-29 with the agent module).
JUST_MOD = re.compile(r'^mod\??\s+([a-zA-Z][\w-]*)', re.M)


def justfile_recipes(root):
    """Recipe names plus module names from the root .justfile."""
    text = COMMENT.sub('', (root / '.justfile').read_text())
    return set(JUST_RECIPE.findall(text)) | set(JUST_MOD.findall(text))
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
    recipes = justfile_recipes(root)

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


# -- skill files themselves (the `skill-files` check) -----------------------

FRONTMATTER_NAME = re.compile(r'^name: (.+)$', re.M)
FRONTMATTER_DESC = re.compile(r'^description: (.+)$', re.M)
# A description may not carry a repo path (skill `new-skill`'s rule); this
# matches the shapes that read as one -- a repo top-level prefix or a
# leading ./ ../ -- without firing on topic shorthand like
# "impermanence/initrd" or a mount point like "/root".
DESC_PATH = re.compile(
    r'(?:\.{1,2}/|(?:wiki|flake|\.agents|\.github|scripts)/[\w./-]+)')
DESC_SENTENCE_END = re.compile(r'[.!?](?:\s|$)')
DESC_MAX_WORDS = 30  # REVIEW only: the rule is one sentence of purpose;
                     # the ceiling just names the outliers worth re-reading.
FRONTMATTER_WHEN = re.compile(r'^when_to_use:(.*)$', re.M)
FRONTMATTER_KEY = re.compile(r'^([^\s:#][^:]*):', re.M)
# Keys a SKILL.md here may carry. Claude Code reads more (allowed-tools,
# model, ...), but none is used here, and a misspelt key (`when-to-use`,
# `whenToUse`) is silently ignored by every harness -- so an unknown key is
# a finding, and adopting a new one means extending this set on purpose.
FRONTMATTER_KEYS = {'name', 'description', 'when_to_use'}
# `!` then a backtick, at line start or after whitespace: Claude Code's
# inline injection syntax.
INJECTION = re.compile(r'(?:^|\s)!`')
# Claude Code truncates description + when_to_use, combined, at this many
# characters in the skill listing (code.claude.com/docs/en/skills,
# checked 2026-10-01; configurable per-user via skillListingMaxDescChars).
LISTING_CAP = 1536
WHEN_MAX_WORDS = 40  # REVIEW only: "short trigger phrases" -- the full
                     # trigger detail lives in ## Applies to.
# A plain (unquoted) YAML scalar can't open with an indicator character or
# contain ': ' / ' #' -- a value like `"push", "ship it"` parses as a quoted
# string followed by junk. The hand-rolled regexes above would read such a
# line fine while the harness's YAML parser rejects the whole frontmatter.
YAML_PLAIN_BAD_START = tuple('"\'[]{}>|*&!%@`,?#-')
YAML_PLAIN_BAD_INNER = (': ', ' #')
# Repo-rooted backtick paths worth existing-checking inside skill prose.
# Prefix-scoped on purpose: bare names (`hosts.nix`, `serve.nix`) are
# shorthand for paths this repo writes several ways, and checking them
# needs exactly the judgement calls `wiki_stale_refs.py` exists for.
ROOTED_PATH = re.compile(
    r'`((?:wiki|flake|\.agents|\.github|scripts)/[\w./-]+)`')
MD_LINK = re.compile(r'\]\(([^)\s]+)\)')
FENCE = re.compile(r'\s*```')
BARE_JUST = re.compile(r'\bjust ([a-z][\w-]*)')


def _just_mentions_in_skill(text):
    """`just <recipe>` mentions in a skill file: backticked anywhere, bare
    inside fenced code blocks. Prose ("just say what you're doing") sits
    outside both, which is what keeps this free of the false positives a
    raw-text scan drowns in."""
    found = [m.group(1) for m in JUST_MENTION.finditer(text)]
    in_fence = False
    for line in text.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
        elif in_fence:
            found.extend(m.group(1) for m in BARE_JUST.finditer(line))
    return found


def check_skill_files(root):
    """The `.agents/skills/**/*.md` files themselves -- see `skill-files` in
    the module docstring for why. Four lookups shared with the wiki-side
    checks (recipes, skill mentions, links, and a prefix-scoped form of
    links' path existence), plus the two only a SKILL.md has: frontmatter
    name/directory agreement and the description shape skill `new-skill`
    specifies."""
    skills_dir = root / '.agents' / 'skills'
    if not skills_dir.exists():
        return []
    recipes = justfile_recipes(root)
    real = {p.name for p in skills_dir.iterdir() if p.is_dir()}

    findings = []
    for path in sorted(skills_dir.rglob('*.md')):
        rel = path.relative_to(root)
        text = path.read_text()

        for m in MD_LINK.finditer(text):
            target = m.group(1).split('#', 1)[0]
            if (not target or '<' in target or '*' in target
                    or target.startswith(('http://', 'https://', 'mailto:'))):
                continue
            if not (path.parent / target).resolve().exists():
                findings.append(
                    f"MISSING LINK  {rel}: ({m.group(1)}) resolves to nothing")

        seen = set()
        for mention in _just_mentions_in_skill(text):
            if mention in seen:
                continue
            seen.add(mention)
            tokens = mention.split()
            if not tokens or '<' in mention:
                continue
            name = (tokens[1] if '=' in tokens[0] and len(tokens) > 1
                    else tokens[0])
            if name not in recipes:
                findings.append(
                    f"UNKNOWN RECIPE  {rel}: `just {mention}` -- "
                    f"'{name}' is not a recipe in .justfile")

        for m in ROOTED_PATH.finditer(text):
            candidate = m.group(1).rstrip('/')
            if '<' in candidate or '*' in candidate:
                continue
            if not (root / candidate).exists():
                findings.append(
                    f"MISSING PATH  {rel}: `{candidate}` does not exist "
                    f"at the repo root")

        for m in SKILL_MENTION.finditer(text):
            name = m.group(1) or m.group(2)
            if name not in real:
                findings.append(
                    f"UNKNOWN SKILL  {rel}: '{name}' has no "
                    f".agents/skills/{name}/ directory")

        if path.name != 'SKILL.md':
            continue
        if not text.startswith('---'):
            findings.append(
                f"NO FRONTMATTER  {rel}: SKILL.md must open with a "
                f"--- name/description block")
            continue
        head = text.split('---', 2)[1]
        name_m = FRONTMATTER_NAME.search(head)
        desc_m = FRONTMATTER_DESC.search(head)
        if not name_m:
            findings.append(f"NO NAME  {rel}: frontmatter has no name:")
            continue
        if name_m.group(1).strip() != path.parent.name:
            findings.append(
                f"NAME MISMATCH  {rel}: frontmatter name "
                f"'{name_m.group(1).strip()}' != directory "
                f"'{path.parent.name}'")
        if not desc_m:
            findings.append(
                f"NO DESCRIPTION  {rel}: frontmatter has no description:")
            continue
        desc = desc_m.group(1).strip()
        why = (" -- skill `new-skill`'s description rule, enforced here "
               "so it stays true")
        if DESC_PATH.search(desc):
            findings.append(
                f"DESCRIPTION SHAPE  {rel}: description contains a repo "
                f"path{why}")
        if '(' in desc:
            findings.append(
                f"DESCRIPTION SHAPE  {rel}: parenthetical in "
                f"description{why}")
        if len(DESC_SENTENCE_END.findall(desc)) > 1:
            findings.append(
                f"DESCRIPTION SHAPE  {rel}: description is more than one "
                f"sentence{why}")
        if len(desc.split()) > DESC_MAX_WORDS:
            findings.append(
                f"REVIEW   {rel}: description is {len(desc.split())} words "
                f"(over {DESC_MAX_WORDS}) -- scope detail that belongs in "
                f"## Applies to")
        findings += _check_skill_frontmatter_extras(rel, head, desc)
        findings += _check_skill_injection(rel, text)
    return findings


def _check_skill_injection(rel, text):
    """Dynamic context injection (an exclamation mark then a backticked
    command, or a fence opened with three backticks and an exclamation mark)
    runs a shell command when the skill loads, with no prompt. This repo
    doesn't use it; skill `new-skill` says why."""
    findings, in_fence = [], False
    for n, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("```"):
            if not in_fence and stripped.startswith("```!"):
                findings.append(
                    f"INJECTION  {rel}:{n}: a ```! block runs at skill load "
                    f"-- not used in this repo (skill `new-skill`)")
            in_fence = not in_fence
            continue
        if not in_fence and INJECTION.search(line):
            findings.append(
                f"INJECTION  {rel}:{n}: an inline !`command` runs at skill "
                f"load -- not used in this repo (skill `new-skill`); in "
                f"prose, don't put ! directly before a backtick")
    return findings


def _check_skill_frontmatter_extras(rel, head, desc):
    """Unknown keys, YAML plain-scalar safety, and the optional
    `when_to_use` -- short trigger phrases Claude Code appends to the
    description in its skill listing (other harnesses ignore it, so
    ## Applies to stays the full trigger detail). Skill `new-skill` has the
    description / when_to_use / Applies-to split."""
    why = (" -- skill `new-skill`'s when_to_use rule, enforced here so it "
           "stays true")
    findings = []
    for m in FRONTMATTER_KEY.finditer(head):
        key = m.group(1).strip()
        if key not in FRONTMATTER_KEYS:
            findings.append(
                f"UNKNOWN KEY  {rel}: frontmatter key '{key}' -- not one of "
                f"{sorted(FRONTMATTER_KEYS)}; a misspelt key is silently "
                f"ignored, so extend FRONTMATTER_KEYS deliberately")
    for line in head.splitlines():
        if line[:1].isspace() and line.strip():
            findings.append(
                f"FRONTMATTER SHAPE  {rel}: indented/continuation line "
                f"'{line.strip()[:40]}' -- every value stays on one line")
    values = [('description', desc)]
    when_m = FRONTMATTER_WHEN.search(head)
    when = when_m.group(1).strip() if when_m else None
    if when is not None:
        values.append(('when_to_use', when))
        if not when:
            findings.append(
                f"WHEN_TO_USE SHAPE  {rel}: when_to_use is empty or a "
                f"block scalar{why}")
        if DESC_PATH.search(when):
            findings.append(
                f"WHEN_TO_USE SHAPE  {rel}: when_to_use contains a repo "
                f"path{why}")
        total = len(desc) + len(when)
        if total > LISTING_CAP:
            findings.append(
                f"WHEN_TO_USE SHAPE  {rel}: description + when_to_use is "
                f"{total} chars, over Claude Code's {LISTING_CAP}-char "
                f"listing cap -- the tail is truncated")
        if len(when.split()) > WHEN_MAX_WORDS:
            findings.append(
                f"REVIEW   {rel}: when_to_use is {len(when.split())} words "
                f"(over {WHEN_MAX_WORDS}) -- trigger detail that belongs in "
                f"## Applies to")
    for key, value in values:
        if value and (value.startswith(YAML_PLAIN_BAD_START)
                      or any(s in value for s in YAML_PLAIN_BAD_INNER)):
            findings.append(
                f"FRONTMATTER SHAPE  {rel}: {key} is not a plain YAML "
                f"scalar (leading indicator character, ': ', or ' #') -- "
                f"the harness's YAML parse fails or truncates it; reword")
    return findings


# Both current instances end the enrolled-host list right before an em-dash;
# `re.S` lets `.*?` cross the markdown line-wrap between them.
ENROLLS_CLAIM = re.compile(r'enrolls\s+(.*?)—', re.S)
HOST_TOKEN = re.compile(r'`(nire-[\w-]+)`')


def enrolled_hosts(root):
    """host names anchored under .sops.yaml's own `keys:` list -- the actual
    enrollment, independent of the "enrolls ..." prose that names the same
    set by hand in more than one doc."""
    p = root / 'flake' / 'modules' / 'general-config' / 'system' / 'secrets' / '.sops.yaml'
    return set(re.findall(r'&(nire-[\w-]+)', COMMENT.sub('', p.read_text())))


def check_secrets(root):
    """Every "`.sops.yaml` ... enrolls `host`, `host`, ... —" claim
    (wiki/impermanence-and-secrets.md and .agents/rules/secrets.md both
    make this exact claim by hand, in the same shape) against
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


CADDY_NIX = pathlib.Path('flake/modules/general-config/homelab/reverse-proxy/caddy/caddy.nix')
# Where the retired path-prefix routes live since 2026-09-13 -- moved out of
# caddy.nix's history section, still the record of what `/grafana/` and
# `/git/` were.
CADDY_RETIRED = pathlib.Path('wiki/categories/reverse-proxy-history.md')
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
# shorthand (homelab/00-INDEX.md) -- deliberately NOT a bare `/name/` pattern,
# which would also match ordinary filesystem paths like `/root/` or
# `/persist/` that have nothing to do with Caddy.
ROUTE_MENTION = re.compile(r'ts-cube\.moose-micro\.ts\.net/([\w-]+)/|`\.\.\./([\w-]+)/`')


def caddy_routes(root):
    """path-prefix name -> True if Caddy strips it before reaching the app,
    False if it's kept -- read straight out of caddy.nix's own embedded
    Caddyfile string rather than assumed (the "read the built artifact,
    don't guess" reasoning lessons-learned.md §41 is about, applied statically
    here instead of via `caddy adapt`). Cube-only and there's exactly one
    caddy.nix, so no need for find_categories-style generality.

    CADDY_RETIRED is read for the same names because the wiki legitimately
    documents routes that are gone (`/grafana/`, `/git/`, retired 2026-09-07)
    and the mention check would otherwise flag every one of them. Those
    blocks used to sit in caddy.nix's own history section, which is why this
    passed before they moved to the wiki 2026-09-13 -- the set of names has
    not changed, only where the file holding them lives. This has never
    distinguished live from retired: it catches a doc naming a prefix that
    exists nowhere at all, which is the check's whole claim."""
    routes = {}
    for rel in (CADDY_NIX, CADDY_RETIRED):
        p = root / rel
        if not p.exists():
            continue
        text = p.read_text()
        routes.update({name: False for name in CADDY_KEPT_PATH.findall(text)})
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


# Pages styleguide.md's Content-shape section exempts from carrying a
# `## Contents` block at all. NOT the same set as SIBLING_EXEMPT, and
# conflating the two is a mistake that has already been made here:
# `-history.md` is exempt from needing a *sibling* but still carries a
# Contents block like any other page, and reverse-proxy-history.md lost its
# one on 2026-09-12 on the strength of that confusion. Keep the two lists
# apart and named for what they exempt.
CONTENTS_EXEMPT = (
    re.compile(r'^wiki/lessons-learned(\.md|/)'),
    re.compile(r'-for-agents\.md$'),
)


def check_contents(root):
    """Two halves, both about a page's `## Contents` block.

    - **stale**: a page that has one, whose list no longer matches its own
      headings -- a heading renamed, added, or removed without regenerating.
    - **missing** (added 2026-09-12): a page that should have one and
      doesn't. This used to be skipped outright, on the reasoning that
      styleguide.md is where the expectation is written down -- which left
      the failure it was silent about indistinguishable from correct
      behaviour: a page whose block was *deleted* looked exactly like a page
      correctly exempt. That is not hypothetical; reverse-proxy-history.md
      lost its block on 2026-09-12 and `check` stayed green.

    A page with no `##` headings at all is skipped either way -- there is
    nothing to list, and `gen-contents` declines to write an empty block."""
    findings = []
    for path in wiki_md(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text()
        actual = actual_contents_items(text)
        expected = expected_contents_items(text)
        if actual is None:
            if expected and not any(rx.search(rel) for rx in CONTENTS_EXEMPT):
                findings.append(
                    f"MISSING CONTENTS  {path}: has {len(expected)} `##` "
                    f"headings but no '## Contents' block, and isn't exempt "
                    f"(styleguide.md, Content shape) -- add one with "
                    f"`gen-contents {path}`")
            continue
        if actual != expected:
            findings.append(
                f"STALE CONTENTS  {path}: its '## Contents' list doesn't "
                f"match its own headings -- fix with `gen-contents {path}`")
    return findings


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
    """"all N hosts"-shaped prose across wiki/ + AGENTS.md, the exact claim
    AGENTS.md's Platform-support section got wrong ("all five hosts" when
    hosts.nix defines four). Class-scoped variants ("all three NixOS
    hosts", "Two of the three NixOS hosts") are checked against that
    class's own count. The counts *table* this used to check too is
    generated since 2026-10-01 (wiki_gen.py's `module-counts` region)."""
    return _host_count_findings(root)


def _host_count_findings(root):
    """The whole of `counts` since the table half became generated
    (2026-10-01); split out 2026-09-12, when the table half could return
    early on a missing table."""
    findings = []
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
# the drift `wiki/00-INDEX.md` warns about. The siblings written when this
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


# The other shape a long page may take (since 2026-10-01): one page whose
# first section after `## Contents` is `## Quick facts` -- the dense,
# agent-facing summary folded in at the top instead of kept as a sibling.
# For pages where the sibling was mostly a restatement of a page that was
# already compact, so every edit paid twice for no reading saved. The check
# only asks that the section exist and come first; it is what an agent
# lands on, so anywhere further down defeats it.
QUICK_FACTS_HEADING = 'Quick facts'


def _first_section(text):
    """The page's first `## ` heading other than `## Contents`, or None."""
    for line in text.splitlines():
        if line.startswith('## ') and line[3:].strip() != 'Contents':
            return line[3:].strip()
    return None


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
    for path in wiki_md(root, f'*{SIBLING_SUFFIX}.md'):
        source = path.with_name(
            path.name[:-len(f'{SIBLING_SUFFIX}.md')] + '.md')
        pairs.append((source, path))
    return pairs


def check_siblings(root):
    """The `<page>.md` / `<page>-for-agents.md` pairing, four ways:

    - **orphan** -- a sibling whose source page doesn't exist (a rename that
      moved one half of the pair).
    - **missing** -- a page over SIBLING_REQUIRED_WORDS with no sibling,
      not on the exempt list, and not opening with `## Quick facts` (the
      folded single-page shape, QUICK_FACTS_HEADING).
    - **stale** -- the guard the whole split rests on. Both pages carry
      `_Last modified:_` (checked for shape by `dates`); editing a page's
      content bumps it, per styleguide.md. So a sibling dated EARLIER than
      its source means the source was edited and the sibling wasn't, which
      is the failure mode `wiki/00-INDEX.md`'s "why a link layer, not a
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

    for path in wiki_md(root):
        rel = path.relative_to(root).as_posix()
        if path.name.endswith(f'{SIBLING_SUFFIX}.md') or path in have_sibling:
            continue
        if any(rx.search(rel) for rx in SIBLING_EXEMPT):
            continue
        text = path.read_text()
        words = _words(text)
        if words >= SIBLING_REQUIRED_WORDS:
            if _first_section(text) == QUICK_FACTS_HEADING:
                continue  # single page, dense summary folded in at the top
            findings.append(
                f"MISSING SIBLING  {rel}: {words} words, over the "
                f"{SIBLING_REQUIRED_WORDS}-word line, but has neither a "
                f"{path.stem}{SIBLING_SUFFIX}.md nor `## "
                f"{QUICK_FACTS_HEADING}` as its first section")
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
    for path in wiki_md(root):
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


LESSON_ENTRY = re.compile(
    r'^- \*\*§(\d+)\*\* \[[^\]]+\]\((lessons-learned/[^)]+)\) — .+$')
LESSON_ARTICLE = re.compile(r'^(\d+)-[a-z0-9-]+\.md$')


# A rule's frontmatter: `paths:` then `  - "glob"` items, nothing else.
RULE_FRONTMATTER = re.compile(r'\A---\n(.*?)\n---\n', re.S)
RULE_PATH_ITEM = re.compile(r'^\s+-\s+"([^"]+)"\s*$')


def glob_regex(pattern):
    """A Claude Code `paths:` glob as a regex over repo-relative paths:
    `**/` is zero or more directories, `**` anything, `*` and `?` stay
    within one path segment, `{a,b}` is alternation. Enough for the shapes
    rules here use; brackets are taken literally."""
    out, i = [], 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith('**/', i):
            out.append('(?:.*/)?'); i += 3; continue
        if pattern.startswith('**', i):
            out.append('.*'); i += 2; continue
        if c == '*':
            out.append('[^/]*')
        elif c == '?':
            out.append('[^/]')
        elif c == '{':
            end = pattern.find('}', i)
            if end < 0:
                out.append(re.escape(c))
            else:
                alts = pattern[i + 1:end].split(',')
                out.append('(?:' + '|'.join(re.escape(a) for a in alts) + ')')
                i = end + 1
                continue
        else:
            out.append(re.escape(c))
        i += 1
    return re.compile(''.join(out) + r'\Z')


def tracked_files(root):
    import subprocess
    r = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'],
                       capture_output=True, text=True, check=True)
    return [f for f in r.stdout.split('\0') if f]


def check_rules(root):
    """`.agents/rules/*.md`: frontmatter is exactly a non-empty `paths:`
    list, every glob matches a tracked file, and AGENTS.md names the file.
    See the module docstring's `rules` entry for why each matters."""
    findings = []
    rules = rule_files(root)
    if not rules:
        return findings
    tracked = tracked_files(root)
    agents = (root / 'AGENTS.md').read_text()
    for path in rules:
        rel = path.relative_to(root).as_posix()
        if rel not in agents:
            findings.append(
                f"UNLISTED RULE  {rel}: AGENTS.md does not name it -- "
                f"harnesses without rule support would never see it")
        m = RULE_FRONTMATTER.match(path.read_text())
        if not m:
            findings.append(
                f"RULE FRONTMATTER  {rel}: no leading --- frontmatter block "
                f"-- without `paths:` it loads in every session")
            continue
        lines = [l for l in m.group(1).splitlines() if l.strip()]
        if not lines or lines[0].rstrip() != 'paths:':
            findings.append(
                f"RULE FRONTMATTER  {rel}: frontmatter must be `paths:` "
                f"followed by a list of quoted globs")
            continue
        globs = []
        for line in lines[1:]:
            item = RULE_PATH_ITEM.match(line)
            if not item:
                findings.append(
                    f"RULE FRONTMATTER  {rel}: unexpected line {line!r} -- "
                    f"`paths` is the only field Claude Code reads, as "
                    f'`  - "glob"` items')
                continue
            globs.append(item.group(1))
        if not globs:
            findings.append(f"RULE FRONTMATTER  {rel}: `paths:` is empty")
        for g in globs:
            rx = glob_regex(g)
            if not any(rx.match(f) for f in tracked):
                findings.append(
                    f"DEAD RULE GLOB  {rel}: {g!r} matches no tracked file "
                    f"-- the rule would never load")
    return findings


def check_lessons(root):
    """See the module docstring's `lessons` entry."""
    findings = []
    page = root / 'wiki' / 'lessons-learned.md'
    art_dir = root / 'wiki' / 'lessons-learned'
    entries = {}
    for line in page.read_text().splitlines():
        if not line.startswith('- **§'):
            continue
        m = LESSON_ENTRY.match(line)
        if not m:
            findings.append(f"MALFORMED LESSON  {page}: {line[:70]}")
            continue
        n, link = int(m.group(1)), m.group(2)
        if n in entries:
            findings.append(f"DUPLICATE LESSON  {page}: §{n} has two entries")
        entries[n] = link
        if not link.startswith(f'lessons-learned/{n}-'):
            findings.append(
                f"LESSON LINK  {page}: §{n} links {link}, not its own article")
        for field in ('Home: ', 'Enforced: '):
            if f'. {field}' not in line:
                findings.append(f"LESSON FIELD  {page}: §{n} has no `{field.strip()}`")
    articles = {}
    for p in sorted(art_dir.glob('*.md')):
        m = LESSON_ARTICLE.match(p.name)
        if not m:
            findings.append(f"LESSON ARTICLE NAME  {p}: not `<N>-<slug>.md`")
            continue
        n = int(m.group(1))
        if n in articles:
            findings.append(f"DUPLICATE ARTICLE  {p}: §{n} already has {articles[n].name}")
        articles[n] = p
        if not p.read_text().startswith(f'# {n}. '):
            findings.append(f"LESSON ARTICLE TITLE  {p}: title isn't `# {n}. ...`")
    top = max([*entries, *articles], default=0)
    for n in range(1, top + 1):
        if n not in entries:
            findings.append(f"MISSING LESSON  {page}: no entry for §{n}")
        if n not in articles:
            findings.append(f"MISSING ARTICLE  {art_dir}: no {n}-*.md for §{n}")
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
    this file. An earlier version used the NEXT_HEADING span and silently
    deleted the intro prose that used to sit between the Contents heading
    and the first real section, on every such page the first time it ran.
    Bullet-list-only replacement can't repeat that mistake no matter what
    sits after the list -- which is still the guarantee that matters even
    though the 2026-09-11 reorder moved that prose above the Contents
    block (styleguide.md, Content shape), leaving nothing between the list
    and the first heading on a paired page.

    Position-independent by construction: when a `## Contents` heading
    already exists this rewrites it in place, wherever it sits. The
    insert-from-scratch path puts a new block immediately before the page's
    first real `##` heading, which is where styleguide.md's Content shape
    section wants it -- below the title, the date, the intro prose and the
    condensed-version pointer. It lands after the date instead only on a
    page with no `##` heading at all to sit above."""
    text = path.read_text()
    items = expected_contents_items(text)
    if not items and not CONTENTS_HEADING.search(text):
        # Nothing to list and no block to rewrite: inserting an empty
        # `## Contents` heading here is worse than leaving the page alone.
        # `check_contents` passes either way (it compares an empty list
        # against an empty list), so this is only about not writing
        # something a reader has to wonder about.
        print(f"SKIP {path}: no `##` headings to list")
        return
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
        # Past the intro prose too, to just above the first real section --
        # the title/date position above is only the floor, used when the page
        # has no `##` heading to sit in front of.
        first_heading = next((i for i, l in enumerate(lines)
                              if i >= insert_at and l.startswith('## ')), None)
        if first_heading is not None:
            insert_at = first_heading
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

    cmds = ('imports', 'table', 'recipes', 'skills', 'skill-files',
            'secrets', 'routes', 'links', 'anchors', 'contents', 'dates',
            'counts', 'generated', 'siblings', 'lessons', 'rules', 'check')
    if cmd not in cmds:
        print(__doc__)
        sys.exit(2)

    findings = []
    if cmd in ('imports', 'check'):
        findings += check_imports(root)
    if cmd in ('table', 'check'):
        findings += check_table(root)
    if cmd in ('recipes', 'check'):
        findings += check_recipes(root)
    if cmd in ('skills', 'check'):
        findings += check_skills(root)
    if cmd in ('skill-files', 'check'):
        findings += check_skill_files(root)
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
    if cmd in ('generated', 'check'):
        # Imported here, not at the top: wiki_gen imports this module for
        # its parsers, and a top-level import each way would be a cycle.
        import wiki_gen
        findings += wiki_gen.check(root)
    if cmd in ('siblings', 'check'):
        findings += check_siblings(root)
    if cmd in ('lessons', 'check'):
        findings += check_lessons(root)
    if cmd in ('rules', 'check'):
        findings += check_rules(root)

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
