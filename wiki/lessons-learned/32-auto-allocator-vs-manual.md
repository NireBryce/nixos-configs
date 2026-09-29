# 32. An auto-allocator that cannot see manual entries will collide with them

_Last modified: 2026-09-29_

§32 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §32's full account.

`nire/system/containers/containers.nix` (then `virtualization.nix`) set
`autoSubUidGidRange = true` on a `container` user while pinning
`subUidRanges = [{ startUid = 100000; ... }]` on `elly` four lines below. It
evaluated. It had evaluated for a week. Both users would have shared one
subordinate UID range.

nixpkgs allocates auto ranges in `update-users-groups.pl`'s `allocSubUid`,
which walks 100000, 165536, … and rejects a candidate only if it is in
`%subUidsUsed` (handed out this activation) or `%subUidsPrevUsed` (read back
from `/var/lib/nixos/auto-subuid-map`). **Explicitly-declared `subUidRanges`
are never added to either set.** The manual pin is not a reservation; it is
invisible to the thing doing the reserving.

What makes this the interesting kind of bug is why `nire-durandal` was fine.
`elly` had been auto-allocated 100000 *before* the pin was written, so 100000
is in that host's map file, so `%subUidsPrevUsed` contains it, so the allocator
steps past it to 165536. The machine's accumulated state was concealing the
defect. On `nire-testbed` or `nire-lego`, neither of which has been installed
yet and neither of which has a map file, the same config produces
`elly:100000:65536` and `container:100000:65536` — two users, one range, with
rootless podman storage on both sides of it.

- **When an option has both an "auto" mode and a "manual" mode for the same
  resource, find out whether auto can see manual before using both.** Often it
  cannot, and nothing says so.
- §24 is "compare against what is deployed, not the last commit". This is its
  inverse and it bites in the other direction: **a host that works can be
  working because of state a fresh one will not have.** Four of the six
  `nixosConfigurations` here have never been installed, so "durandal is fine"
  is not the same claim as "the config is right".
