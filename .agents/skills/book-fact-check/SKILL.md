---
name: book-fact-check
description: Fact-checks the mdBook chapters against the repo with read-only agents, applies the verified corrections, and rebuilds the book.
when_to_use: Asked to fact-check, lint or proofread the book, or after code or docs that the book describes change.
---

# Fact-checking the book

## Applies to

The mdBook under `book/src/`: checking its claims against the repo and its
prose against the book's own rules. The procedure is `wiki-fact-check`'s;
this skill adds the book's mechanical checks, what the agents must look at
that a wiki page does not have, and the build. Not for writing new chapters
or for wiki pages (`wiki-fact-check`).

The book is a snapshot of how things work, written from the wiki, the code
and the git history, and every chapter says where each claim came from. That
makes it checkable and makes it drift: when a script, hook, skill or doc it
describes changes, the chapter is the part nobody edits.

## Steps

1. **Mechanical pass first.** `just agent book-lint check` fails on a dead
   link, a `#fragment` that matches no heading, a chapter missing from
   `SUMMARY.md`, an ISO date, or a count of hosts, hooks, skills and the like
   (the book's maintainability rule: point at the file or command that lists
   them, because the number goes stale). `just agent book-lint prose` ranks
   the longest paragraphs and sentences and counts filler and vague openers
   (`This`, `It`) for the clarity pass. `check` also runs in preflight.
2. **Group the chapters** (`wiki-fact-check`, step 1). Chapters that read the
   same machinery go together: the hook and guard chapters to one agent, the
   module-system chapters to another, the git and host chapters, and the
   introduction, user and darwin chapters plus the glossary. Four groups
   covered thirteen chapters in five to nine minutes each.
3. **Launch the agents** with `wiki-fact-check`'s prompt, plus these claim
   types for the book:
   - every `Source:` line: each path exists and the quoted section or heading
     exists in that file;
   - every code excerpt matches the file it comes from, or the chapter says it
     is abridged (open the real file and compare);
   - the lesson numbers (`§N`) a chapter cites say what the chapter says;
   - commit hashes resolve with `git cat-file -t` (a shallow clone may lack
     one: that is UNCHECKABLE, not WRONG);
   - each `Check:` line is what the named command actually shows, from reading
     the script;
   - every `Unverified:` marker, and whether the source now answers it;
   - the glossary entries, and that the same term means the same thing in
     every chapter that uses it;
   - issue links: read each (the GitHub issue tools work read-only) and see
     whether it is still open. A closed issue means the chapter describes
     behavior that has changed.
4. **Verify, route, apply** (`wiki-fact-check`, steps 4 to 6). Some findings
   belong to the repo, not the book: a wrong comment or docstring is fixed at
   its source in a boyscouting change, and a defect becomes an issue that the
   chapter states the current behavior of and links. Apply the book's
   corrections to chapters no agent is still reading.
5. **Clarity pass**, using the `prose` report: split paragraphs over about a
   hundred words, break sentences over about forty, replace a vague `This` or
   `It` with its noun, cut repeated multi-sentence explanations to one place
   plus a pointer, and keep a term's definition to a clause with a glossary
   link. Do not change what a sentence claims; if you must, it was a fact-check
   finding.
6. **Build and re-check.**

   ```sh
   mdbook build book -d <scratch>/bookout     # cargo install mdbook --locked, if absent
   just agent book-lint check
   just agent book-render <scratch>/bookout <scratch>/book.html
   ```

   The render is one self-contained page, for the person who asked to read the
   book before it is proposed.
7. **Commit and ship.** Book changes in one commit, one push, then `ship`.
   The book links wiki paths, so a change that moves wiki files also needs
   `just agent move-refs` and a pass over the book's links.

## Calibrate

Do not turn a fact-check into a rewrite: a correction changes the claim the
evidence contradicts and nothing around it. The book links open issues on
purpose; when one closes, update the chapter that cites it in the same change.

## See also

`wiki-fact-check`, `docs-audit-all`, `trim-docs`, `fact-hygiene`,
`propose-issue`, `ship`.
