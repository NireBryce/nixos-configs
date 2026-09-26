# Practicing a workplace coding environment

_Last modified: 2026-09-26_

What cube's forge ([forgejo.md](forgejo.md)) plus its Actions runner
([git-forge](../categories/git-forge.md)'s runner module) is *for*, beyond
hosting mirrors: the experience of **submitting code in a workplace**, as
the developer, not the ops side. The infrastructure already existed; the
part that makes it a workplace is the policy and habit layer on top.

## Contents

- [What actually differs from solo dev](#what-actually-differs-from-solo-dev)
- [The setup, per practice repo](#the-setup-per-practice-repo)
- [The loop to drill](#the-loop-to-drill)
- [The review gap](#the-review-gap)
- [See also](#see-also)

## What actually differs from solo dev

Not the tooling — the gates, and who stands behind them:

- **You cannot push to main.** Branch protection converts "commit and
  push" into "get the change through a gate."
- **CI runs before anyone reads it.** Your change is built and tested by
  the forge before review starts.
- **Someone else approves.** The forge enforces that an approval exists.

Forgejo does all three. The one thing a forge cannot supply is the
reviewer — see [the review gap](#the-review-gap).

## The setup, per practice repo

All of it is repo settings and files in the repo — not infrastructure:

1. **Branch protection** — repo → Settings → Branch: protect `main`, disallow
   direct pushes, require a pull request, require status checks to pass,
   require one approval.
2. **CI** — `.forgejo/workflows/ci.yaml`, GitHub-Actions syntax.
   `runs-on: nix` for everything (the runner's label `nix:host` is name
   `nix`, executor `host`) (jobs run directly in the runner
   VM; declare toolchains with nix profiles or setup-* actions). Workflow
   mechanics:
   [forgejo.md → CI](forgejo.md#ci-forgejo-actions).
3. **Scaffolding** — issue and PR templates, and the habit of `fixes #N`
   in the PR body so the merge closes the issue.

Gate CI on what a workplace gates on: **test suite, linter, type checker**
— e.g. `pytest` + `ruff` + `mypy` for Python, the equivalents per
ecosystem. Practice on a **normal application repo** for exactly this
reason: `nix flake check` is a niche flavor of that experience, not the
common one.

## The loop to drill

File an issue → branch from it → commits → PR that references it → CI
green → review → merge → delete branch. This repo's `ship` skill is
already that loop by choice; here it is *enforced* by the forge, with a
CI status and a review sitting in the middle. That difference — the work
being gated rather than self-graded — is the whole point.

One mechanical wrinkle: Forgejo blocks approving your own PR, so the
approval gate needs a second account (`forgejo admin user create`,
[forgejo.md](forgejo.md#signing-in-and-why-theres-no-sign-up)). Useful not
because you fool anyone, but because it forces the discipline of writing
PRs that stand without you in the room.

## The review gap

The honest limit: a second account is you in a reviewer's chair, not a
reviewer. Two free ways to get a real one:

- **Open source.** Real maintainers, real review comments — and reading
  an unfamiliar codebase is itself the core workplace skill.
- **Agent review** — the `review` skill pattern pointed at the practice
  repo's PRs. Approximates the cold reviewer who finds what you missed;
  none of the social negotiation.

## See also

- [forgejo.md](forgejo.md) — the forge itself: signing in, cloning, CI
  workflows.
- [pending-setup.md](pending-setup.md) — item 8, the one-time runner
  bootstrap.
- [git-forge](../categories/git-forge.md) — the runner's configuration and
  registration scheme.
