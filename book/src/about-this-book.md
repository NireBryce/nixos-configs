# About this book

## Who wrote it

Coding agents drafted this book from the wiki, the code, comments and git
history, and the repo owner reviewed it. They also wrote most of the rest of
the repository (see `README.md`). The owner has corrected the claims the repo
depends on; the remainder is agent output with less scrutiny. Treat the
book as reliable but unproven, and check statements that matter against the
code each chapter lists under Sources.

Mechanical checks back this up: lints compare documentation against code, and
each checker has a test with a case it must catch. The chapters on
[agents in the repo](agents-in-the-repo.md),
[checks and guards](agent-checks-and-guards.md) and
[git and agent workflows](git-and-agent-workflows.md) describe them.

## Book and wiki

The wiki is the source for facts. The book links into it instead of
duplicating it. When the book disagrees with the wiki or the code, the wiki
and the code win.

## Links to `../../wiki/...`

Links to `../../wiki/...` point at files in the repository. They work when you read the
Markdown on GitHub or in a checkout. The published site rewrites them to
GitHub URLs at build time ([`book.yml`](../../.github/workflows/book.yml),
[`book_pages_links.py`](../../.agents/scripts/book_pages_links.py)).

## Unverified claims

A claim the agents could not confirm from the repo is listed under "Not
checked" at the end of its chapter. Read those as open questions. The wiki
marks the same thing inline, with `UNVERIFIED` or "not confirmed live".

## Sources

- `README.md`, `AGENTS.md`
- `.github/workflows/book.yml`
- `.agents/scripts/book_pages_links.py`
