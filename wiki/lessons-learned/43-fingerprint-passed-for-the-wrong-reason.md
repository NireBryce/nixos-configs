# 43. A fingerprint check can pass for the wrong reason — dead code looks exactly like safe code until you make it live

_Last modified: 2026-09-09_

§43 of [lessons-learned.md](../lessons-learned.md#43-a-fingerprint-check-can-pass-for-the-wrong-reason--dead-code-looks-exactly-like-safe-code-until-you-make-it-live) — that page keeps the one-line version of every lesson; this is §43's full account.

2026-08-27, the `dirsAsCategory.nix` deduplication (`flake/doc/dirsAsCategory.md`'s
History section has the full account; this is the general shape). 37
byte-identical copies of the category-collection logic got factored into one
shared file, `modules/_lib/category-collector.nix`. Verified properly for
that part: fingerprints (`drvPath`) taken for `nire-durandal` and
`nire-cube` before touching anything, one file converted and re-checked
before rolling out to the other 36, `just modules` clean throughout, every
host's `drvPath` byte-identical after. That part of the change was fine.

While the logic was already in one place, adding "stop at a nested
category's own boundary and reference its aggregate by name, instead of
re-walking its files from scratch" looked like the obvious next
improvement — cheap to write once, and `nire/hardware/amd` plus `homelab`'s
seven children were sitting right there as real nested categories to apply
it to. Wrote it, and the same `drvPath` fingerprint check that had just
verified the refactor passed again, unchanged.

It should not have. The check passing meant nothing here, for a specific,
findable reason: `modulesOf` (the function that walks a category's immediate
subdirectories) calls the collection function already *inside* each
subdirectory, so a boundary check placed inside that function never gets a
chance to examine an immediate subdirectory — like `amd` or
`virtualization` — as something to delegate to. Every nested category this
repo has is exactly one level deep. The delegation code was real, compiled,
and syntactically what I'd described to Elly in conversation — and entirely
dead, for a reason that took tracing the actual call graph to see, not
reasoning from the diff. The fingerprint check "passed" because nothing had
actually changed, not because the change was safe.

Went back and made it live — applying the same check one level higher, so it
would actually fire at the depth this repo has — specifically to find out
whether it *was* safe, rather than leaving the question open. It wasn't:
`homelab` delegating to `virtualization`'s aggregate instead of walking it
independently silently dropped `libvirt-vm-llm-sandbox` from `nire-cube`'s
`systemd.services`. Cause: `virtualization-cube.nix` sits bare in
`virtualization/`'s own root, deliberately excluded from `virtualization`'s
*own* aggregate (a category collects from subdirectories only), but reaches
`nire-cube` today only because `homelab` walks into `virtualization/`
independently, as *its own* subdirectory, where that same file is not
excluded (`wiki/categories/virtualization.md` already documented this exact
quirk, from the 2026-08-24 `homelab` consolidation — I had read that page
earlier the same session and still nearly re-broke the thing it describes).
Delegating collapses that independence: `homelab` would then get only what
`virtualization`'s own aggregate decided to include, which is deliberately
short one file. `drvPath` alone would not have shown this either, cheaply —
what actually surfaced it was evaluating `config.systemd.services` directly
and checking for the one service name that mattered, before and after.

Reverted the delegation entirely at first, on the reasoning that no
measurable performance difference had ever been established to justify
carrying the risk (a full toplevel eval here is ~8s, dominated by evaluating
real NixOS/HM modules, not by re-walking a handful of category directories
twice) — until asked, in this same conversation, whether the near-miss could
be fixed instead of just avoided. It could: `homelab`'s independent walk
into `virtualization/` was the *only* reason `virtualization-cube.nix`
reached `nire-cube` at all, so the fix isn't "don't delegate," it's
"delegate to the child's aggregate for what it collects, but separately
re-collect any bare files sitting in its own root too" — the exact two
things a plain recursive walk used to do at once, split back into two
explicit steps instead of one implicit one. Verified properly this time,
not just on the one host that had already broken: a full attribute-set diff
(`environment.systemPackages`, `systemd.services`, `users.users`) against
the pre-refactor baseline, on all six configurations in the repo, not only
`nire-cube`. All identical; `libvirt-vm-llm-sandbox` included.

Three things to carry forward, not just about this mechanism. **A
fingerprint matching proves the version you ran it against, and says nothing
about whether the code path it's meant to guard actually executed** — trace
whether new logic is reachable before trusting a green check that could
easily be green because the logic never ran. **"Looks like the obvious next
optimization" is exactly the moment to check for a documented quirk the
optimization would collapse**, not proceed because the refactor immediately
upstream just verified clean — `wiki/categories/virtualization.md` had the
answer already written down, from three days earlier, and reading it after
the fact (once the regression was already suspected) rather than before
writing the code is what let it get built at all. And **finding a real bug
in an optimization is not automatically a reason to drop the optimization**
— reverting outright was the right call the moment the bug was found and
nothing more was known, but it was a first move, not the last one: the
actual defect (delegation losing a category's own bare files) had a specific,
narrow fix once named, and it was only right to stop there because someone
asked "can this be fixed instead" rather than accepting "revert" as the
finished answer.
