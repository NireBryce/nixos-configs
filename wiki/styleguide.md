# Wiki style guide

_Last modified: 2026-09-11_

## Contents

- [Directory hierarchy](#directory-hierarchy)
- [Naming](#naming)
- [Content shape](#content-shape)
- [Two audiences per page](#two-audiences-per-page)
- [Linking](#linking)
- [Keeping this from rotting](#keeping-this-from-rotting)
- [See also](#see-also)

> **Condensed version:**
> [styleguide-for-agents.md](styleguide-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

How this wiki itself is organized and written — as opposed to
[conventions.md](conventions.md), which is the *repo's* style guide (Nix
formatting, `just` commands, the `ship` flow). Read this before adding a
page, splitting one into a subdirectory, or reorganizing links; it's the
place the reasoning behind [README.md](README.md)'s "why a link layer, not
a rewrite" gets turned into concrete rules.

## Directory hierarchy

Two tiers for the *configuration* side, plus one escape hatch — and one
separate tier for the *usage* side:

- **`wiki/*.md`** — cross-cutting topics that don't belong to one category:
  `overview.md` (the newcomer's on-ramp, deliberately written to be read
  first), `architecture.md`, `hosts.md`, `disk-formatting.md` (the one
  runbook-shaped page here — ordered steps, closer to a `homelab/` usage
  page, but scoped to a `flake/modules/` mechanism so it stays in this
  tier), `history.md`, `impermanence-and-secrets.md`, `open-threads.md`,
  `traps-and-skills.md`, `conventions.md`, this file.

  Two pages in this tier are the exception to "index over restatement"
  below: `lessons-learned.md` and `module-style-guide.md` moved in verbatim
  from `claude cave/` when that directory was retired 2026-09-02 (two
  others moved with them — `impermanence-stage1-migration.md` and
  `kde-to-wayland-migration.md` — and were removed 2026-09-05 —
  `history.md`) — real, synthesized content because there's nothing else
  for it to link to.
  `history.md` stays the index into `lessons-learned.md`;
  `conventions.md` stays the index into `module-style-guide.md` — the same
  split as a category page and its deep-dive. `lessons-learned.md`'s long
  entries live as per-§ articles in `wiki/lessons-learned/` (added
  2026-09-09, `<n>-<slug>.md`): the page keeps every § number and a
  one-line summary linking to each article.
- **`wiki/categories/<name>.md`** — one page per real category, i.e. a
  directory under `flake/modules/` holding its own `dirsAsCategory.nix`
  (see [architecture.md](architecture.md)). Indexed in
  [categories/README.md](categories/README.md)'s table (`Category |
  Directory | Class(es) | Imported by` — deliberately no per-category file
  count column; see that page's own note on why). Deliberately *not*
  covered by their own category page: `nirePackages/*` subcategories
  (single-package files, already self-explanatory from a glance) and
  `nireHost/*` per-host bundles (host definitions, not categories — see
  [hosts.md](hosts.md) instead).
- **`wiki/homelab/`** — the usage tier, added 2026-08-24 with
  [creating-golinks.md](homelab/creating-golinks.md). Pages about operating
  a service this fleet runs, for a reader who wants to *do something with
  it* rather than edit `flake/modules/`. `README.md` is the index.

  **Name a page for what the reader wants to do, not for the module.**
  `forgejo.md` works as a bare noun because the tool's name is what you'd
  search for and the page is about the whole service. A plural noun does
  not: `golinks.md` read as *a list of the fleet's go/ links* — which is a
  thing that could plausibly exist and isn't what the page is — so it was
  renamed `creating-golinks.md` on 2026-09-11, taking the verb-phrase shape
  [reaching-services.md](homelab/reaching-services.md) already used. When a
  noun name would name a collection the reader might expect to be listed
  there, use the verb.

  [reaching-services.md](homelab/reaching-services.md) is the one page not
  about a single service: a cross-service page earns its place here when
  the *thing being explained is the arrangement* — the URL map, why the
  certificate is trusted, which layer to suspect. Prefer a service page;
  reach for this shape only when the alternative is repeating yourself.

  It's a separate tier from `categories/` because the two rot differently:
  a category page goes stale when the config changes, a usage page when the
  *service* changes — possibly with no commit to this repo at all.

  **"Index over restatement" is relaxed here, with a condition.** The real
  source is often the running service's own help endpoint
  (`http://go/.help`), not a file in this repo, so a page here may hold
  synthesized content — but it must say **what was verified against the
  live service and what was only transcribed**, and point at the live
  source as canonical. `creating-golinks.md`'s closing section is the pattern.
- **`wiki/categories/<name>/`** — the escape hatch, used exactly once so
  far ([shell-config](categories/shell-config/README.md)). A category
  outgrows a single file not by being long, but by one specific *member*
  of it accumulating an investigation or set of findings that don't belong
  in the category-level summary. When that happens: the directory's
  `README.md` becomes the category article (what `<name>.md` used to be),
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
- **`wiki/categories/<name>-history.md`** — a sibling file rather than a
  new directory, used when a category page has accumulated resolved
  incidents (a first-switch failure since fixed, a superseded plan, a
  regression that's been fixed twice) whose *outcome* still matters but
  whose blow-by-blow doesn't need loading every time the category page is
  read. Added 2026-09-03 across `backup`, `virtualization`, `shortlinks`,
  `git-forge`, `monitoring`, `reverse-proxy` — `backup-history.md` also
  absorbed what had been a "Background" section on
  [homelab/backup-runbook.md](homelab/backup-runbook.md), so a usage-tier
  page's history can live on its category's history page too rather than
  needing its own. **Don't reach for this by default** — most of what
  reads as "history" in a category page is actually mechanism explained
  through its discovery, and that stays put; see "index over restatement"
  below for why narrating *how* something was verified is not the same as
  narrating *that* it used to be broken. The test: does understanding the
  *current* setting/behavior require this paragraph, or only understanding
  how it came to be that way? Only the second kind moves. The main page
  keeps a one-to-two-sentence summary and a link — never a bare pointer
  with nothing — so a reader loses no context skimming the main page, only
  the full narrative.

## Naming

- kebab-case, matching the category or subject exactly
  (`shell-config.md`/`shell-config/`, `blesh.md`, `carapace.md`).
- `README.md` is reserved for the index file of a directory
  (`categories/README.md`, `categories/shell-config/README.md`) — never
  used as a single-topic page name.

## Content shape

- **Every page opens with a `_Last modified: YYYY-MM-DD_` line**, right
  after the title and before `## Contents` (added wiki-wide 2026-09-06):

  ```
  # Page title

  _Last modified: 2026-09-06_

  ## Contents
  ```

  Absolute date, same rule as everywhere else on this page — the point is a
  reader can tell at a glance how stale a page might be without opening
  `git log`. **Whoever edits a page's actual content bumps this line to
  today in the same change**; a purely mechanical touch (a `gen-contents`
  run, a typo fix) doesn't need to. `wiki/scripts/check_wiki.py dates`
  checks that the line exists and is shaped right (part of `just
  wiki-lint`), but — like every other date claim in this repo — can't check
  that it's still *true*; that's on the editor, the same discipline skill
  `wiki-sync` already asks for everywhere else on a page.
- **Every page opens with a `## Contents`** — a bullet list of section links,
  one per `##` heading on the page, placed right after the title and before
  any intro prose (added wiki-wide 2026-09-01, for browsability: a reader
  lands knowing the page's shape before reading a word of it). Each link's
  target is GitHub's own heading-slug algorithm applied to that heading's
  text: lowercase, strip everything that isn't a letter/digit/space/hyphen/
  underscore (backticks, colons, periods, em-dashes, quotes all disappear; a
  removed character between two spaces leaves a double hyphen once spaces
  become hyphens), then replace each space with a hyphen.

  **Don't hand-derive this.** `wiki/scripts/check_wiki.py` implements the
  exact algorithm (`github_slug`, reverse-engineered against real rendered
  GitHub output, not assumed) and two checks that use it: `anchors` (every
  link with a `#fragment` resolves to a real heading on its target page) and
  `contents` (every page's `## Contents` list still matches its own current
  headings) — both part of `check`/`just wiki-lint`. After adding, renaming,
  or removing a heading, run `python3 wiki/scripts/check_wiki.py gen-contents
  <the page>` to regenerate its Contents block correctly rather than editing
  it by hand; it's idempotent, so running it on an already-correct page is a
  no-op. This exists because a hand-derived anchor already got it wrong once
  — `categories/homelab.md`'s link into `virtualization.md`'s `` `VMs/_lib/
  libvirt-vm.nix` `` heading — and sat wrong until `anchors` caught it.

  **Exception: `lessons-learned.md`, `lessons-learned/` articles, and
  `-for-agents.md` siblings carry no Contents block** (the first two relaxed
  2026-09-09, siblings 2026-09-11 — on a page whose whole purpose is
  information density, an anchor list is the first thing that has to go). Entries there are located by §
  number — grep `## 43\.` — so a 46-line anchor list was paid on every full
  read of the wiki's largest page for no navigational gain. The `contents`
  check only validates pages that have a Contents block, so this needed no
  linter change, only this sentence.
- Category pages follow **what's in it → mechanism notes specific to that
  category, if any → imported by → see also**. This is the same
  what/why/traps depth the rest of the wiki holds itself to, per
  [categories/README.md](categories/README.md).
- **Index over restatement.** Link to the real source — a module's own
  header comment, `CLAUDE.md`, a skill, a `bugs pending submission/`
  writeup — rather than copying its content into the wiki page. When in
  doubt, the wiki page should be short and the linked file should be where
  the reader actually ends up.
- **`wiki/homelab/` pages are the other exception**, on the terms in the
  hierarchy section above: synthesized content is allowed because the
  source is the live service, but the page owes the reader an explicit
  verified-vs-transcribed split.
- **The one exception is a deep-dive page** (`blesh.md`, `carapace.md`):
  those *are* allowed to hold real, synthesized findings, because they
  document a cross-file or cross-tool interaction that has no single
  natural home to live in as a code comment. That's the whole reason the
  finding earned a wiki page instead of one file's header — don't apply
  "index over restatement" so strictly there that the finding has nowhere
  to live.
- If an ordinary category or topic page starts accumulating actual facts
  instead of links — a paragraph explaining *why*, not just *where* —
  that's a sign the fact belongs in the linked file's own header instead,
  per this repo's standing convention of keeping explanations next to the
  code they explain (see [conventions.md](conventions.md)).
- **Dates are absolute**, not relative ("2026-08-22", never "today" or
  "last week") — the same rule this repo applies everywhere, and the only
  thing that lets a stale wiki page be recognized as stale by its own text
  rather than by someone noticing the drift.
- **See-also sections point two ways**: sideways to sibling pages, and
  outward to the general form of a trap where one exists — a skill, most
  often (e.g. `shell-config` → the `home-manager-dotfiles` skill). The wiki
  page stays the specific instance; the skill stays the reusable lesson.

## Two audiences per page

A page over **1,000 words** gets a `<page>-for-agents.md` sibling. The
original stays what it is — explanation, for a human reading it cold. The
sibling is the same ground at maximum information density, for an agent that
loaded it to get one thing done and pays for every token of narrative around
that thing.

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

Exempt from *needing* one: [lessons-learned.md](lessons-learned.md) and its
`lessons-learned/` articles (already written agent-facing, located by §
number rather than read front-to-back) and `<name>-history.md` pages
(resolved incidents — already the moved-out-of-the-way tier). A page under
1,000 words *may* have one, but usually shouldn't: at that size the
sibling's own title, date line and back-link start to outweigh what
compressing it saves. `homelab/README.md` was tried and dropped for exactly
that reason.

### This is deliberate duplication, and it is the only kind here

[README.md](README.md)'s "why a link layer and not a rewrite" section says
in as many words that this repo has been bitten repeatedly by one fact
living in two places and drifting. That objection is correct. The split is
worth it anyway — the two readers genuinely want different documents — but
only because it is the one duplication in this wiki with a **mechanical**
guard under it rather than a convention someone has to remember:

`check_wiki.py siblings` (part of `just wiki-lint`) checks that

- every sibling has a source page, and every page over the line has a
  sibling;
- **the sibling's `_Last modified:_` does not predate its source's** — so
  editing a page's content without following in its sibling, in the same
  change, fails the run and names the pair. This is the whole point of the
  check; everything else it does is bookkeeping.
- **or the sibling carries a `_Sibling reviewed:_` line** dated at or after
  its source's, with a reason:

  ```
  _Sibling reviewed: 2026-09-11 -- header reorder, no facts moved_
  ```

  That is the one legitimate way to land a source edit with genuinely
  nothing to sync — a reorder, a typo, a rewording of something the sibling
  already states its own way. It means someone read the source as of that
  date and confirmed this page needs no change. **Don't reach for it to
  avoid the work**; a real fact in a source edit belongs in both halves, and
  the reason you write is what a reviewer checks that against. Added
  2026-09-11: before it, the only way to land a no-op source edit was to bump
  the sibling's date, which the paragraph below tells you not to do and which
  no check could ever catch. A future-dated review is itself a finding.
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
  links back up (`categories/README.md` ↔ a category page ↔ its
  deep-dive pages).
- A path containing a space (anything under `bugs pending submission/`) has
  to be wrapped in `<...>` for the markdown link target to parse — see the
  entries in [open-threads.md](open-threads.md) for the pattern. `claude
  cave/` used to be the other example of this until it was retired
  2026-09-02 and its files moved into `wiki/` proper, whose own paths never
  have spaces.
- Verify a link resolves before leaving it. There's no automated check for
  this (see below); a quick `[ -e "$(dirname "$file")/$link" ]` per link
  after any move or rename catches what proofreading misses.

## Keeping this from rotting

No CI ties these links together — a moved or renamed file breaks them
silently, and a stale fact (a category's member count, a host's
import list) just sits there until someone happens to read it against the
source. The rule is the same one `CLAUDE.md` holds itself to: whichever
session's change makes a wiki page stale — moving a file it links to,
changing a fact it states, adding a member to a category it describes —
corrects that page in the same change, not as a follow-up. Treat an
undated or vaguely-dated claim on a wiki page the same way `CLAUDE.md`
says to treat one in itself: a claim about when someone last looked, not a
guarantee about the tree today.

## See also

- [README.md](README.md) — the wiki's own top-level index and the "why a
  link layer, not a rewrite" reasoning this style guide turns into rules.
- [categories/README.md](categories/README.md) — the category-index page,
  and the concrete precedent note for the `shell-config/` split.
- [conventions.md](conventions.md) — the repo's own style guide (Nix
  formatting, comments, `just`), as distinct from this page.
