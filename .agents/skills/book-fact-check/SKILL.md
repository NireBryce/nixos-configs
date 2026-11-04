---
name: book-fact-check
description: Fact-checks the mdBook chapters against the repo with read-only agents, applies the verified corrections, and rebuilds the book.
when_to_use: Asked to fact-check, lint or proofread the book, or after code or docs that the book describes change.
---

# Fact-checking the book

## Applies to

The mdBook under `book/src/`: checking its claims against the repo and its
prose against the book's own rules. The procedure is `wiki-fact-check`'s;
this skill adds the book's mechanical checks, the extra claim types the
agents must check, and the build. Not for writing new chapters or for wiki
pages (use `wiki-fact-check`).

The book is a snapshot written from the wiki, the code and the git history.
Every chapter names the source of each claim. That makes the claims
checkable, and they go stale when a script, hook, skill or doc changes and
nobody edits the chapter.

## Book prose conventions

The clarity pass (step 5) enforces these rules:

- **"nire" is the repository author.** Write "nire", lower-case mid-sentence,
  where the text means the person who directs the agents, owns the repo and
  decides (who asks for a filing, who merges, who switches a host). The
  introduction names them once. Keep "the user" where it means a user of the
  system in an example or the account the config builds (the user
  environment, the user's fonts, `elly-user.nix`). This differs from
  `AGENTS.md`, which has agents write "the user" in repo text; the book names
  the author at their request.
- Point at the file or command that lists a thing instead of stating a count,
  a date or a host roster (`book-lint check` enforces it).
- Define a term in one clause at first use, then link the glossary.
- Terminology: module file, NixOS/Home Manager/darwin module, flake-parts
  module (`wiki/config-structure/module-files.md`).

## Steps

1. **Mechanical pass.** `just agent book-lint check` fails on a dead link, a
   `#fragment` that matches no heading, a chapter missing from `SUMMARY.md`,
   an ISO date, or a count of hosts, hooks, skills and the like (counts go
   stale; point at the file or command that lists them). `just agent
   book-lint prose` ranks the longest paragraphs and sentences and counts
   filler and vague openers (`This`, `It`) for the clarity pass. `check` also
   runs in preflight.
2. **Group the chapters** (`wiki-fact-check`, step 1). Put chapters that
   describe the same machinery together: the hook and guard chapters to one
   agent, the module-system chapters to another, the git and host chapters,
   and the introduction, user and darwin chapters plus the glossary. Four
   groups covered thirteen chapters in five to nine minutes each.
3. **Launch the agents** with `wiki-fact-check`'s prompt, plus these claim
   types for the book:
   - every `Source:` line: each path exists and the quoted section or heading
     exists in that file;
   - every code excerpt matches the file it comes from, or the chapter says it
     is abridged (open the real file and compare);
   - the lesson numbers (`§N`) a chapter cites say what the chapter says;
   - commit hashes resolve with `git cat-file -t` (a shallow clone may lack
     one: report UNCHECKABLE, not WRONG);
   - each `Check:` line matches what the named command shows, judged by
     reading the script;
   - every `Unverified:` marker, and whether the source now answers it;
   - the glossary entries, and that each term means the same thing in every
     chapter that uses it;
   - issue links: read each one (the GitHub issue tools work read-only) and
     note whether it is still open. A closed issue means the chapter
     describes behavior that has changed.
4. **Verify, route, apply** (`wiki-fact-check`, steps 4 to 6). Some findings
   belong to the repo, not the book: fix a wrong comment or docstring at its
   source in a boyscouting change, and file a defect as an issue that the
   chapter links and describes the current behavior of. Apply the book's
   corrections to chapters no agent is still reading.
5. **Clarity pass**, using the `prose` report: split paragraphs over about a
   hundred words, break sentences over about forty, replace a vague `This` or
   `It` with its noun, cut repeated multi-sentence explanations to one place
   plus a pointer, and keep a term's definition to a clause with a glossary
   link. Do not change what a sentence claims; a change of claim is a
   fact-check finding.
6. **Build and re-check.**

   ```sh
   mdbook build book -d <scratch>/bookout     # cargo install mdbook --locked, if absent
   just agent book-lint check
   just agent book-render <scratch>/bookout <scratch>/book.html
   ```

   The render is one self-contained page, for the person who asked to read the
   book before it is proposed.
7. **Commit and ship.** Make one commit and one push for the book changes,
   then run `ship`. The book links wiki paths, so a change that moves wiki
   files also needs `just agent move-refs` and a pass over the book's links.

## Calibrate

A fact-check is not a rewrite: a correction changes the claim the evidence
contradicts and nothing around it. The book links open issues on purpose;
when one closes, update the chapter that cites it in the same change.

## See also

`wiki-fact-check`, `docs-audit-all`, `trim-docs`, `fact-hygiene`,
`propose-issue`, `ship`.
