# Wiki style guide

How this wiki itself is organized and written — as opposed to
[conventions.md](conventions.md), which is the *repo's* style guide (Nix
formatting, `just` commands, the `ship` flow). Read this before adding a
page, splitting one into a subdirectory, or reorganizing links; it's the
place the reasoning behind [README.md](README.md)'s "why a link layer, not
a rewrite" gets turned into concrete rules.

## Directory hierarchy

Two tiers, plus one escape hatch:

- **`wiki/*.md`** — cross-cutting topics that don't belong to one category:
  `architecture.md`, `hosts.md`, `history.md`, `impermanence-and-secrets.md`,
  `open-threads.md`, `traps-and-skills.md`, `conventions.md`, this file.
  These span multiple categories or aren't tied to a `flake/modules/`
  directory at all.
- **`wiki/categories/<name>.md`** — one page per real category, i.e. a
  directory under `flake/modules/` holding its own `dirsAsCategory.nix`
  (see [architecture.md](architecture.md)). Indexed in
  [categories/README.md](categories/README.md)'s table (`Category |
  Directory | Class(es) | Members | Imported by`). Deliberately *not*
  covered by their own category page: `nirePackages/*` subcategories
  (single-package files, already self-explanatory from a glance) and
  `nireHost/*` per-host bundles (host definitions, not categories — see
  [hosts.md](hosts.md) instead).
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

- Category pages follow **what's in it → mechanism notes specific to that
  category, if any → imported by → see also**. This is the same
  what/why/traps depth the rest of the wiki holds itself to, per
  [categories/README.md](categories/README.md).
- **Index over restatement.** Link to the real source — a module's own
  header comment, `CLAUDE.md`, a skill, a `bugs pending submission/`
  writeup — rather than copying its content into the wiki page. When in
  doubt, the wiki page should be short and the linked file should be where
  the reader actually ends up.
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
- A path containing a space (anything under `claude cave/` or `bugs
  pending submission/`) has to be wrapped in `<...>` for the markdown link
  target to parse — see the entries in
  [open-threads.md](open-threads.md) for the pattern.
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
