# 11. Read the links in a comment before deleting the code they annotate

_Last modified: 2026-09-29_

§11 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §11's full account.

I was about to replace a `requires`/`after` block whose lines carried a
systemd.unit(5) URL. The user asked whether I had read it. I had not.

`Requires=` is an activation dependency, `After=` is ordering, neither implies
the other, and the manual says to pair them. Dropping `requires` would have
changed the failure mode from "does not run" to "runs and fails" — on the
service that deletes `/root`.
