# 48. A recorded change is not an applied change, when the thing changed lives outside the repo

_Last modified: 2026-09-29_

§48 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §48's full account.

2026-09-10, cube. `acl-diff-applied.hujson` recorded a `svc:glance` autoApprover that had never been POSTed, and `svc-glance.json` described a Service object that had never been created — so `glance.moose-micro.ts.net` didn't resolve anywhere while the repo looked complete and a merged PR claimed the work was done. A file named for what *was applied* is still just a file; only the control plane knows. The fix is a command that asks it (`just tailscale-acl diff`, now reporting "no difference"), not a more carefully written record. Generalizes past this repo: any state whose home is an external API needs a diff against the API, not a checked-in mirror trusted on sight.
