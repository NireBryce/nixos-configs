---
name: explain-tricky-code
description: How to write comments that teach a user or contributor a module or lib function whose design isn't obvious from its code, so they learn what it does, why it's shaped that way, and what breaks if they change it.
---

# Explaining tricky code so a user or contributor can follow it

The technique: write the comments the way you'd give a conference talk on
the code to an audience of mixed skill levels — start from the problem,
build up, show diagrams, answer the questions a smart listener would ask.
(Was `talk-style-explainer` until 2026-09-28, named for that technique
rather than for when to reach for it.)

## Applies to

A `.nix` module or `_lib/` function whose *mechanism* is the hard part —
something a competent reader can't follow from the code alone, where the
questions are "why is it shaped like this" and "what breaks if I touch it".
Asked for directly ("explain this like a talk", "make these comments
clearer for someone new"), or offered when a comment rewrite keeps coming
back as "still confusing".

The worked example is `flake/modules/_lib/category-collector.nix`, rewritten
this way 2026-09-28 after three rounds of denser comments that each read
as clear only to someone who already knew the answer.

Not this skill:

| ask | what to do |
|---|---|
| an ordinary module (a package, a service toggle) | `wiki/module-style-guide.md` — dense, one-line comments; a talk is noise there |
| the bottom-of-file history block | skill `trim-history`; history stays compressed, never talk-style |
| a wiki page | `wiki/styleguide.md`; a page already has a human half and an agent half |
| tightening existing prose | skill `trim-docs` |

**This is the opposite trade from the rest of the repo.** The house style
is maximum density; a talk-style header is several times longer. Use it
only where the mechanism earns it, and say so when offering it — the user
picks.

## The shape

Each part is a ruled section (`just ruled-heading "<title>"`, 78 wide — the
house heading width), in this order. Skip a part the subject doesn't need;
don't reorder.

1. **Self-introduction, on its own line, by full path.** "This file,
   `modules/_lib/category-collector.nix`, is the logic that every
   `dirsAsCategory.nix` runs." A reader who landed here from a grep knows
   where they are before anything else.
2. **The problem this solves — what first, why second.** Open with one
   plain statement of what the thing *does* ("turns its folder into one
   importable module that imports every module under that folder"). Only
   then the why: describe the obvious alternative and list its concrete
   failure modes ("rename a module and every list that named it is
   wrong"). The why is what makes the design feel inevitable instead of
   arbitrary.
3. **Background the mechanism leans on — only that.** If the design only
   makes sense given something outside the file (flake-parts' per-class
   `flake.modules`, how import-tree filters paths), explain that piece with
   one real example from the tree (`zsh.nix` declaring both a `nixos` and a
   `homeManager` half). Not a tutorial on the whole tool.
4. **The rule, stated once, then a diagram.** One sentence a first-time reader could
   repeat back ("a category imports every `.nix` module under its folder,
   however deep"), followed by a tree of *real* paths annotated with what
   happens to each. Then the consequences, as a short list.
5. **The clever part.** The non-obvious mechanism (nested categories
   referenced by name instead of re-walked), introduced from the reader's
   likely first guess ("it could walk in and list everything by hand. But
   …"), with a small flow diagram.
6. **Things that look movable and aren't — as Q&A.** Each is a cleanup a
   smart reader would attempt. Write the question they'd ask, then the
   answer, visibly separated:

   ```
   # 1. Q: The shim passes in `shimFile`. Why not work it out in here?
   #
   #    A: `__curPos.file` is answered when the file is *read* ...
   ```

   The Q/A split matters: the earlier prose version buried which sentence
   was the question.
7. **Traps.** What fails silently, and what (if anything) catches it.
8. **How to change it safely.** Which doc to read first and how to verify
   (a fingerprint diff, an attribute-set diff) — the one paragraph a
   future editor most needs.

Comments on the individual functions use the same voice, but short: what
this piece does, in terms of the sections above, and any "why not the
obvious thing" that belongs at that line specifically.

## Voice

- **Define every term at first use**, in words ("a folder with a
  `dirsAsCategory.nix` in it is a *category*"). Mixed audience means
  someone in the room doesn't know it.
- **Real examples from this tree, never placeholders.** `fzf.nix` in
  `find/`, not `foo.nix` in `bar/`. A real path can be checked; a made-up one
  can't.
- **Lead with the reader's question.** "Why not just hand over the names?"
  then the answer. Questions are how a talk keeps a mixed room with it.
- **Plain words where they're exact.** "Folder" is fine; so is "the
  collector looks each name up". Keep the precise term too when it's the
  one they'll grep for (`forClass`, `imports`).
- **No history in the body.** "We used to…" goes in the bottom `history`
  block. The body describes what is.

## Diagrams

Use one wherever the explanation would otherwise be "imagine a folder
containing…". Inline in `#` comments, 78 columns:

- **Trees**: Unicode box drawing, the shape `tree` prints (`├──`, `│`,
  `└──`) — the repo already uses `─` in every ruled heading. Annotate each
  node in a right-hand column with what happens to it.
- **Flows/decisions**: a small table — input, branch taken, result:

  ```
  #     find/          plain folder    -> walk in          -> fzf, fd
  #     text-tools/    a category      -> add its name     -> ripgrep, bat, ...
  ```

- **Code shapes**: the attribute paths themselves, one per line
  (`flake.modules.nixos.<name>   system config`).

Keep each diagram small enough to check by hand — every node in it is a
claim.

## Verify every claim before landing

A talk-style header makes far more claims than a dense one, and reads as
authoritative. On the worked example, three drafts shipped false
statements that a check caught:

- "Hosts never import individual modules" — `kde-desktop` and `jovian`
  are imported by name. **Any "never"/"always"/"every" gets a grep.**
- "Each category comes out as *up to* three modules" — the code always
  defines all three. **Read the code for the claim, not your model of it.**
- "`just modules` catches a file named differently from its module" — it
  keys by filename and checks nothing of the kind. **A claim that a tool
  catches something needs the tool's source read.**

Checks that worked:

- **Run the real code against the diagram.** For the collector: call it
  with a stub `config` mapping every name to itself, and compare the lists
  to the tree diagram's annotations.
- **Confirm each example exists and says what the prose says** (`ls` the
  path, grep the declaration).
- **Counts** ("~40 folders"): count them, and prefer "~" or no number —
  counts rot (skill `fact-hygiene`).

Then `just preflight` — comment-only edits still have to pass wiki-lint and
the module checks.

## See also

- `flake/modules/_lib/category-collector.nix` — the worked example.
- `wiki/module-style-guide.md` — the dense default this deliberately departs from.
- Skill `fact-hygiene` — writing a fact so it doesn't rot.
- `just ruled-heading` — section headings at the house width.
