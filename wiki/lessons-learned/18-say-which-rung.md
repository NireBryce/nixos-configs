# 18. Say which rung you mean

_Last modified: 2026-09-29_

§18 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §18's full account.

*Evaluates*, *builds*, *runs* — each finds a different class of defect (§25), so
say which you have. Treat an undated "verified" in this repo as *evaluates*.

**And scope the claim.** For most of the port I wrote "nothing in this
repository has ever been built or switched", which is false and reached seven
files before the user caught it. `origin/main` was deployed and already flake-parts;
what was unproven was this branch's 172 commits on top. "This has never worked"
and "this is a large untested delta on something that works" call for different
caution. An overclaim in the safe-sounding direction is still an overclaim.

There is a fourth rung between *evaluates* and *builds*: `nix build --dry-run`
gives the derivation plan — 711 to build, 2840 to fetch, and the fact that
`decky-loader` had nothing cached — without compiling anything. Real
information, and still not a build.
