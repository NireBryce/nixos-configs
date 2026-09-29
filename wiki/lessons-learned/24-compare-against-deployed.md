# 24. Compare against what is deployed, not against the last commit

_Last modified: 2026-09-29_

§24 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §24's full account.

§2 says the repo is not the machine; on the hardware there is finally a way to
act on it. Diffing the branch against the **running system** answered "would
this break the machine" in a way evaluation could not. Persistence, kernel
command line, the password model and the LUKS device were all identical — and
the one real difference, the rollback's mount target moving from
`/dev/mapper/enc` to a by-uuid path, was invisible from the tree, because both
are correct in isolation.

The enabling trick: **a system's `.drv` outlives its inputs' outputs.**
Generation 60's `stage-1-init.sh` had been collected, but its derivation still
held the whole script in `buildPhase`:

```sh
D=$(nix-store --query --deriver /run/current-system)
nix derivation show -r "$D"
```

Declarative users are not in `/etc` under `mutableUsers = false`; they are in a
`users-groups.json` named by `/run/current-system/activate`. That is how "root
has no password, elly's comes from `/persist`" was established rather than
assumed — the difference between a switch and a lockout.

**This evidence expires.** Once the new generation boots and
`nix-collect-garbage` runs, the old baseline cannot be re-derived. Write it down
before switching, not after. `just baseline` does it.
