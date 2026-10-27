# Wiki style guide

_Last modified: 2026-10-27_

A page lives in the directory that matches its reader: `config-structure/`
for how the flake is built (with `config-structure/categories/` for one page per
category), `fleet/` for the hosts and what runs on them, `upkeep-and-admin/` for
recurring chores and expiries, `meta/` for the wiki's own rules and the repo's
history, `homelab/` for using a running service, `experiments/` for open
investigations. Read this
before adding a page, splitting one into a subdirectory, or reorganizing
links. The rules come from [../00-INDEX.md](../00-INDEX.md)'s "Why links and not a
rewrite" paragraph. ([../config-structure/conventions.md](../config-structure/conventions.md) is the repo's own style
guide: Nix formatting, `just` commands, the `ship` flow.)

> **Condensed version:**
> [styleguide-for-agents.md](styleguide-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Directory hierarchy](#directory-hierarchy)
- [Naming](#naming)
- [Content shape](#content-shape)
- [Two audiences per page](#two-audiences-per-page)
- [Linking](#linking)
- [Keeping this from rotting](#keeping-this-from-rotting)
- [See also](#see-also)

## Directory hierarchy

Pages go in one of these places:

- **`wiki/` root** — only the entry points: the two index pages
  (`00-INDEX*.md`, with `README*.md` symlinks), `overview.md` (the newcomer's
  on-ramp, deliberately written to be read first) and `agent-lessons-learned.md`
  with its per-§ directory. Everything else is in a topic folder:
  - **`wiki/config-structure/`** — how the flake is built: `architecture.md`,
    `flake-parts.md`, `flake-parts-port-notes.md`, `module-files.md`,
    `module-style-guide.md`, `where-modules-go.md`, `conventions.md`,
    `impermanence-and-secrets.md` (the mechanism page for the `impermanence`
    and `system` categories), and `categories/` (below).
  - **`wiki/fleet/`** — the machines: `hosts.md`, `disk-formatting.md` (the
    one runbook-shaped page here, scoped to a `flake/modules/` mechanism so it
    stays out of `homelab/`), `name-resolution.md`, `durandal-gaming.md`.
  - **`wiki/upkeep-and-admin/`** — recurring chores: `maintenance.md`,
    `maintenance-schedule.md`, `flake-lock-weekly-bump.md`,
    `temporary-patches-and-hacks.md`.
  - **`wiki/meta/`** — the wiki's own rules and the repo's memory: this file,
    `traps-and-skills.md`, `history.md`, `open-threads.md`, and `scripts/`
    (the wiki's linters and generators).

  Pages in these folders are exceptions to "index over restatement" below
  where they hold synthesized content because there's nothing else for it to
  link to: `agent-lessons-learned.md` and `module-style-guide.md` (moved in
  verbatim from `claude cave/`, retired 2026-09-02) and
  `flake-parts-port-notes.md` (the branch it was salvaged from is gone).
  `meta/history.md` is the index into `agent-lessons-learned.md`, and
  `conventions.md` the index into `module-style-guide.md`: the same split as
  a category page and its deep-dive. Every lesson's full account is a per-§
  article in `wiki/agent-lessons-learned/` (`<n>-<slug>.md`), and
  `agent-lessons-learned.md` is the index: one entry per §, grouped by the
  moment it applies, naming the rule's Home and what Enforced it
  (`check_wiki.py lessons`). A lesson tied to particular paths or commands
  also gets a topic in `.agents/lessons-map.toml`, which a hook uses to remind
  the next agent at that moment.
- **`wiki/config-structure/categories/<name>.md`** — one page per real category, i.e. a
  folder under `flake/modules/` that is a category (see
  [../config-structure/module-files.md](../config-structure/module-files.md)). Indexed in
  [../config-structure/categories/00-INDEX.md](../config-structure/categories/00-INDEX.md)'s table (`Category |
  Directory | Class(es) | Imported by` — deliberately no per-category file
  count column; see that page's own note on why). Deliberately *not*
  covered by their own category page: `packages-config/*` subcategories
  (single-package files, already self-explanatory from a glance) and
  `host-config/*` per-host bundles (host definitions, not categories — see
  [../fleet/hosts.md](../fleet/hosts.md) instead).
- **`wiki/homelab/`** — the usage tier, added 2026-08-24 with
  [creating-golinks.md](../homelab/creating-golinks.md). Pages about operating
  a service this fleet runs, for a reader who wants to *do something with
  it* rather than edit `flake/modules/`. `00-INDEX.md` is the index.

  **Name a page for what the reader wants to do, not for the module.**
  `forgejo.md` works as a bare noun because the tool's name is what you'd
  search for and the page covers the whole service. A plural noun doesn't:
  `golinks.md` read as a list of the fleet's go/ links, so it became
  `creating-golinks.md` (2026-09-11), the verb-phrase shape
  [reaching-services.md](../homelab/reaching-services.md) already used. When a
  noun would name a collection the reader might expect to find listed, use
  the verb.

  [reaching-services.md](../homelab/reaching-services.md) is the one page not
  about a single service. A cross-service page earns its place when the
  *thing being explained is the arrangement* (the URL map, why the
  certificate is trusted, which layer to suspect). Prefer a service page;
  use this shape only when the alternative is repeating yourself.

  It's a separate tier from `categories/` because the two rot differently:
  a category page goes stale when the config changes, a usage page when the
  *service* changes — possibly with no commit to this repo at all.

  **"Index over restatement" is relaxed here, with a condition.** The real
  source is often the running service's own help endpoint
  (`http://go/.help`), not a file in this repo, so a page here may hold
  synthesized content — but it must say **what was verified against the
  live service and what was only transcribed**, and point at the live
  source as canonical. `creating-golinks.md`'s closing section is the pattern.
- **`wiki/experiments/`** — the open-question tier, added 2026-09-13 with
  [durandal-auto-suspend-hang.md](../experiments/durandal-auto-suspend-hang.md).
  One page per problem that is *instrumented but not yet diagnosed*: the
  symptom, what has been established, what has been ruled out, and what is
  currently under test. Distinct from `categories/`, which documents config
  that works, and from [../agent-lessons-learned.md](../agent-lessons-learned.md), which records
  what was learned once it's over.

  **A page here must say which claims are settled and which are still being
  tested.** It exists precisely because the answer isn't known, so its most
  likely failure is reading as though it were — skill `fact-hygiene`. When the
  question closes, the outcome moves to `agent-lessons-learned.md` or the relevant
  category page and the experiment page goes; a page here that has quietly
  become true is a page in the wrong tier.
- **`wiki/config-structure/categories/<name>/`** — the escape hatch, used exactly once so
  far ([shell-config](../config-structure/categories/shell-config/00-INDEX.md)). A category
  outgrows a single file not by being long, but by one specific *member*
  of it accumulating an investigation or set of findings that don't belong
  in the category-level summary. When that happens: the directory's
  `00-INDEX.md` becomes the category article (what `<name>.md` used to be),
  and each deep-dive gets its own sibling page named after its subject —
  `blesh.md`, `carapace.md`, not `notes.md` or `deep-dive-1.md`. Don't add
  a third tier under that; if a deep-dive page itself needs to fork
  further, that's a sign the split is at the wrong level, not a reason to
  nest another directory.
- **`wiki/<any page>-for-agents.md`** — the condensed sibling of a long
  page, added wiki-wide 2026-09-11. Same subject, written for something
  loading it mid-task rather than reading it: facts, paths, option names,
  commands, traps as one-liners, and nothing else. Full rule:
  [Two audiences per page](#two-audiences-per-page) below.
- **`wiki/config-structure/categories/<name>-history.md`** — a sibling file rather than a
  new directory, used when a category page has accumulated resolved
  incidents (a first-switch failure since fixed, a superseded plan, a
  regression that's been fixed twice) whose *outcome* still matters but
  whose blow-by-blow doesn't need loading every time the category page is
  read. A usage-tier page's history can live on its category's history page
  too (`backup-history.md` holds what was a "Background" section of
  [../homelab/backup-runbook.md](../homelab/backup-runbook.md)). **Don't reach for
  this by default.** Most of what reads as "history" in a category page is
  mechanism explained through its discovery, and that stays put. The test:
  does understanding the *current* setting or behavior require this
  paragraph, or only understanding how it came to be that way? Only the
  second kind moves. The main page keeps a one-to-two-sentence summary and a
  link, never a bare pointer, so skimming it loses the narrative but no
  context.

  **The procedure is skill `wiki-history-sweep`**, and
  `just wiki-history-candidates` ranks sections that might qualify
  (reporting only, never fails, and most hits are wrong by design). Issue
  #288.

## Naming

- kebab-case, matching the category or subject exactly
  (`shell-config.md`/`shell-config/`, `blesh.md`, `carapace.md`).
- `00-INDEX.md` is reserved for the index file of a directory
  (`categories/00-INDEX.md`, `categories/shell-config/00-INDEX.md`) — never
  used as a single-topic page name. It sorts to the top of the directory
  listing, which `README.md` (its name until 2026-09-14) did not.
- **Each of those directories also carries a `README.md` symlink to its
  `00-INDEX.md`**, so the name GitHub looks for still exists. Edit the
  `00-INDEX.md`; never write through the symlink, and never link to
  `README.md` from a page. `check_wiki.py`'s `wiki_md()` skips symlinks so
  the same bytes aren't scanned twice — every check that walks `wiki/` goes
  through it for that reason.

## Content shape

- **Every page opens with a `_Last modified: YYYY-MM-DD_` line**, right
  after the title (added wiki-wide 2026-09-06):

  ```
  # Page title

  _Last modified: 2026-09-06_

  <intro prose: what this page is>

  > **Condensed version:** ...

  ## Contents
  ```

  Absolute date, same rule as everywhere else on this page — the point is a
  reader can tell at a glance how stale a page might be without opening
  `git log`. **Whoever edits a page's actual content bumps this line to
  today in the same change**; a purely mechanical touch (a `gen-contents`
  run, a typo fix) doesn't need to. `wiki/meta/scripts/check_wiki.py dates`
  checks that the line exists and is shaped right (part of `just
  wiki-lint`), but — like every other date claim in this repo — can't check
  that it's still *true*; that's on the editor, the same discipline skill
  `wiki-sync` already asks for everywhere else on a page.
- **Every page carries a `## Contents`**: a bullet list of section links,
  one per `##` heading, placed **after** the intro prose and the
  condensed-version pointer, immediately before the first real section. It
  goes below the intro because a section list is useful once you know you're
  on the right page, and the intro is what settles that. Each link's target
  is GitHub's heading slug of that heading's text: lowercase, strip
  everything that isn't a letter, digit, space, hyphen or underscore
  (backticks, colons, periods, em-dashes and quotes all disappear; a removed
  character between two spaces leaves a double hyphen), then replace each
  space with a hyphen.

  **Don't hand-derive this.** `wiki/meta/scripts/check_wiki.py` implements the
  exact algorithm (`github_slug`, reverse-engineered against real rendered
  GitHub output) and two checks that use it: `anchors` (every link with a
  `#fragment` resolves to a real heading on its target page) and `contents`
  (every page's `## Contents` list matches its current headings). Both are
  part of `check` and `just wiki-lint`. After adding, renaming, or removing
  a heading, run `python3 wiki/meta/scripts/check_wiki.py gen-contents <the page>`
  rather than editing the block by hand; it's idempotent. A hand-derived
  anchor already got it wrong once, in `categories/homelab.md`'s link into
  `virtualization.md`'s `` `VMs/_lib/libvirt-vm.nix` `` heading.

  `check_contents` reports **MISSING CONTENTS** for a non-exempt page with
  headings and no block. **The exempt list below is not the same set as the
  `-for-agents` sibling exemption**: `-history.md` pages need no sibling but
  still carry a Contents block. Conflating the two is how
  `reverse-proxy-history.md` lost its block unnoticed.

  **Exception: `agent-lessons-learned.md`, `agent-lessons-learned/` articles, and
  `-for-agents.md` siblings carry no Contents block.** On pages built for
  information density an anchor list is the first thing to go, and entries
  there are located by group or § number (`ls wiki/agent-lessons-learned/43-*`).
  The `contents` check only validates pages that have a block, so this
  needed no linter change.
- Category pages follow **category contents → mechanism notes specific to that
  category, if any → imported by → see also**. This is the same
  what/why/traps depth the rest of the wiki holds itself to, per
  [../config-structure/categories/00-INDEX.md](../config-structure/categories/00-INDEX.md).
- **Index over restatement.** Link to the real source — a module's own
  header comment, `CLAUDE.md`, a skill, a
  `_loose-ends/bugs-pending-submission/` writeup — rather than copying its
  content into the wiki page. When in doubt, the wiki page should be short and the linked file should be where
  the reader ends up.
- **`wiki/homelab/` pages are another exception**, on the terms in the
  hierarchy section above: synthesized content is allowed because the source
  is the live service, but the page owes the reader a verified-vs-transcribed
  split.
- **Deep-dive pages** (`blesh.md`, `carapace.md`) are the third exception.
  They may hold synthesized findings, because they document a cross-file or
  cross-tool interaction with no single natural home as a code comment.
- If an ordinary category or topic page starts accumulating facts instead of
  links (a paragraph explaining *why*, not just *where*), the fact belongs in
  the linked file's own header, per the repo's convention of keeping
  explanations next to the code they explain (see
  [../config-structure/conventions.md](../config-structure/conventions.md)).
- **Dates are absolute** ("2026-08-22", never "today" or "last week"). It's
  the only thing that lets a stale page be recognized as stale by its own
  text.
- **See-also sections point two ways**: sideways to sibling pages, and
  outward to the general form of a trap where one exists — a skill, most
  often (e.g. `shell-config` → the `home-manager-dotfiles` skill). The wiki
  page stays the specific instance; the skill stays the reusable lesson.

## Two audiences per page

A page over **1,000 words** serves an agent one of two ways: a
`<page>-for-agents.md` sibling, or a `## Quick facts` section as its first
section after Contents.

**A sibling** is for a page whose human half is long narrative —
explanation for a human reading cold, history, reasoning — where the dense
version is a fraction of it. The sibling is the same ground at maximum
information density, for an agent that loaded it to get one thing done and
pays for every token of narrative around that thing.

**Quick facts** is for a page that is already compact or procedural: a
runbook, a how-to, a reference page. There a sibling turns out to be a
near-verbatim restatement, and every edit is paid twice for no reading
saved. Fold it: the dense facts (a table where one fits) go in
`## Quick facts` at the top, linked from `00-INDEX-for-agents.md` by its
anchor, and the body stays as written. The tests for folding an existing
pair: the sibling is over ~45% of its source's words, or the two halves
change in the same commits most of the time. `name-resolution.md`,
`maintenance.md`, and `homelab/`'s `creating-golinks.md`,
`reaching-services.md`, `backup-runbook.md` were folded on those grounds
2026-10-01; the old sibling's
name goes in the Quick facts lead-in so a grep for it still lands.

**What goes in the sibling**: the file paths, option and flag names, exact
commands, the shape of a config block, host lists, and every trap as a single
declarative line. Tables over prose wherever a table fits.

**What does not**: how something came to be, what was tried first, who
confirmed it and when, the reasoning behind a choice, meta-commentary about
where else a thing is written down, and see-also sprawl. One see-also line,
pointing back at the human page and at two or three real siblings.

**One thing that looks like narration and isn't**: a qualifier on a claim —
`UNVERIFIED`, `not confirmed live`, `not exercised`, `last checked <date>`.
*Who* verified something and *by what method* is narration and goes;
*whether it was verified at all* is part of the fact and stays. A sibling
that drops those states a guess as settled in the copy most likely to be
acted on. Skill `fact-hygiene` #6.

Exempt from *needing* one: [../agent-lessons-learned.md](../agent-lessons-learned.md) and its
`agent-lessons-learned/` articles (already written agent-facing; the index is
one line per lesson, and an article is found by § number) and `<name>-history.md` pages
(resolved incidents — already the moved-out-of-the-way tier). A page under
1,000 words *may* have one, but usually shouldn't: at that size the
sibling's own title, date line and back-link start to outweigh what
compressing it saves. `homelab/00-INDEX.md` was tried and dropped for exactly
that reason.

### This is deliberate duplication, and it is the only kind here

[../00-INDEX.md](../00-INDEX.md)'s "Why links and not a rewrite" paragraph
says this repo has been bitten repeatedly by one fact living in two places
and drifting. That objection is correct. The split is worth it anyway
because the two readers want different documents, and because it is the one
duplication in this wiki with a **mechanical** guard under it:

`check_wiki.py siblings` (part of `just wiki-lint`) checks that

- every sibling has a source page, and every page over the line has a
  sibling or opens with `## Quick facts`;
- **the sibling's `_Last modified:_` does not predate its source's** — so
  editing a page's content without following in its sibling, in the same
  change, fails the run and names the pair. This is the whole point of the
  check; everything else it does is bookkeeping.
- **or the sibling carries a `_Sibling reviewed:_` line** dated at or after
  its source's, with a reason:

  ```
  _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
  ```

  This is the one legitimate way to land a source edit with nothing to
  sync: a reorder, a typo, a rewording of something the sibling already
  states its own way. It means someone read the source as of that date and
  confirmed this page needs no change. **Don't reach for it to avoid the
  work**; a real fact in a source edit belongs in both halves, and a
  reviewer checks your reason against that. Bumping the sibling's date
  instead is never acceptable, and no check could catch it. A future-dated
  review is itself a finding.
- the two link to each other;
- the sibling fits a 50% word budget — a **REVIEW** finding only, never a
  failure. Density is the goal, and a page that is mostly irreducible
  commands has a floor. Losing a fact to hit the number is the worse
  outcome; cut narration instead, and if what's left is all load-bearing,
  over budget is the right answer.

A category page's `## Imported by` section may live on **either** page of
the pair, or both — `check_imports` checks whichever ones exist — so the
import list doesn't have to be written twice to stay watched.

## Linking

- Relative paths always, recomputed for actual file depth — a link from
  `categories/shell-config/blesh.md` to the repo root needs `../../../`,
  not the `../` that would've been right from `wiki/blesh.md`. Moving a
  page means walking every link in it, not just the ones that "looked"
  affected.
- Link in both directions: an index links down into a page, and that page
  links back up (`categories/00-INDEX.md` ↔ a category page ↔ its
  deep-dive pages).
- **No path in this repo contains a space**, so no link target needs the
  `<...>` wrapper a space forces. Keep it that way; if a spaced path comes
  back, every link target pointing at it must be wrapped in angle brackets
  or the markdown won't parse. (The checker's own link regex reads such a
  wrapper as a live link, so it can't be shown inline here.)
- Verify a link resolves before leaving it. `check_wiki.py anchors` covers
  `#fragment` links; for the path itself, a quick
  `[ -e "$(dirname "$file")/$link" ]` after any move or rename catches what
  proofreading misses.

## Keeping this from rotting

Nothing catches every stale claim: a moved file breaks links silently, and a
stale fact (a category's member count, a host's import list) sits there until
someone reads it against the source. The rule is the one `CLAUDE.md` holds
itself to: whichever change makes a wiki page stale (moving a file it links
to, changing a fact it states, adding a member to a category it describes)
corrects that page in the same change, not as a follow-up. Treat an undated
or vaguely dated claim as a claim about when someone last looked, not a
guarantee about the tree today.

### Generated tables

A table whose every fact the repo already knows is not written by hand at
all. Since 2026-10-01 those tables sit between two comment lines,

```
<!-- generated:<name> -- from <source>, by `just wiki-gen`; ... -->
| ...the table... |
<!-- /generated -->
```

and `just wiki-gen` rewrites everything between them from source. Before
that, a lint check noticed the drift and an agent fixed the row by hand;
the module counts table alone had its rows hand-edited in 24 commits in
September.
Regions (`grep -rn 'generated:' wiki/` lists them): [../fleet/hosts.md](../fleet/hosts.md)'s host table, the Index tables
on [../config-structure/categories/00-INDEX.md](../config-structure/categories/00-INDEX.md), the counts on
[../config-structure/module-style-guide-for-agents.md](../config-structure/module-style-guide-for-agents.md#counts),
and the module-layout diagram on [../config-structure/architecture.md](../config-structure/architecture.md) (a
`Block` in `wiki_gen.py`: no hand-written columns).

**To change a generated fact, change its source** (the start marker names
it) **and run `just wiki-gen`.** An edit inside a region is undone on the
next run. `just wiki-lint` (its `generated` check, also `just wiki-gen
--check`) fails when a region no longer matches its source, so a forgotten
regeneration shows up the same way any other stale claim does.

Some tables mix derived columns with prose no script can derive — a host's
Role, a category's Imported by. Those columns are hand-written and kept
per row across regenerations, and the marker says which they are. A new
row starts with that cell empty and `wiki-lint` fails until someone writes
it; the derived cells around it are never typed by hand.

A regeneration is a mechanical touch: it doesn't bump the page's
`_Last modified:_`, and so doesn't ask for a sibling edit either. If a
`-for-agents` sibling ever needs the same table, it carries the same
region rather than a copy. Adding a new generated table means a `Region`
entry in `wiki/meta/scripts/wiki_gen.py` (its docstring covers the rest) plus a
fixture case in `test_wiki_gen.py`. Claims made inside a sentence — a host
count, the `.sops.yaml` enrollment list — stay in prose and stay under the
existing checks.

## See also

- [../00-INDEX.md](../00-INDEX.md) — the wiki's own top-level index and the "Why links
  and not a rewrite" reasoning this style guide turns into rules.
- [../config-structure/categories/00-INDEX.md](../config-structure/categories/00-INDEX.md) — the category-index page,
  and the concrete precedent note for the `shell-config/` split.
- [../config-structure/conventions.md](../config-structure/conventions.md) — the repo's own style guide (Nix
  formatting, comments, `just`), as distinct from this page.
