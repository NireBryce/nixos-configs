# Wiki style guide

## Contents

- [Directory hierarchy](#directory-hierarchy)
- [Naming](#naming)
- [Content shape](#content-shape)
- [Linking](#linking)
- [Keeping this from rotting](#keeping-this-from-rotting)
- [See also](#see-also)

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

  Four pages in this tier are the exception to "index over restatement"
  below: `lessons-learned.md`, `impermanence-stage1-migration.md`,
  `module-style-guide.md`, and `kde-to-wayland-migration.md` moved in
  verbatim from `claude cave/` when that directory was retired 2026-09-02 —
  real, synthesized content because there's nothing else for it to link to.
  `history.md` stays the index into `lessons-learned.md`;
  `impermanence-and-secrets.md` and `conventions.md` stay the index into the
  other two — the same split as a category page and its deep-dive.
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
  [golinks.md](homelab/golinks.md). Pages about operating a service this
  fleet runs, for a reader who wants to *do something with it* rather than
  edit `flake/modules/`. `README.md` is the index; each service gets a page
  named after the thing you'd search for, not the module (`golinks.md`, not
  `golink.md` — but `forgejo.md`, where the tool's name *is* what you'd
  search for).

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
  source as canonical. `golinks.md`'s closing section is the pattern.
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

## Naming

- kebab-case, matching the category or subject exactly
  (`shell-config.md`/`shell-config/`, `blesh.md`, `carapace.md`).
- `README.md` is reserved for the index file of a directory
  (`categories/README.md`, `categories/shell-config/README.md`) — never
  used as a single-topic page name.

## Content shape

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
