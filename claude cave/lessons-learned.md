# Lessons from the den → flake-parts port

> **Written by Claude Code, for Claude Code**, and largely a record of its own
> mistakes. Written to be read by an agent starting cold, so the "I" throughout
> is a machine with no memory of having done any of it. Useful to a person
> mainly as a list of things that have gone wrong here before. `CLAUDE.md` has
> the rules; this has the scar tissue.

Companion to `old-2026-08-08-PORT-PLAN-(COMPLETED).md` and
`old-historical-TENACITY-PLAN.md`, which record *what* was done. This records how it went wrong in the doing, which is
not recoverable from the tree or the commits.

Three groups, by what could be observed at the time. §§1–18 are the port, from
the darwin laptop, against a tree that could only be evaluated. §§19–24 are the
first session on `nire-tenacity`, where the disk and the build plan became
visible. §§25–31 are from after it booted — see §25. §§32–35 are later work on
already-booted hosts, where the open question stopped being "does it
evaluate" and became "is this true on the hosts that have never been
installed". §35 is the one entry not lived here: a caveat adopted from an
upstream bug report about a change that is merged but unbuilt, and it says so.

Numbers are stable; §§2, 5, 7, 11, 14, 18, 24 and 25 are referenced elsewhere.

---

## 1. A tool that reports success has not thereby been tested

Four tools were written during this port. All four were wrong on first run, and
**all four reported success while being wrong** — none errored, none warned.

| tool | first-run defect |
|---|---|
| `unwrap.py` | silently skipped `sops.nix`, whose declaration ends in `=` with the body on the next line |
| `modules.py orphans` | called eight nested categories dead; `collectModules` recurses, so `rust` in `langs` is also collected by `development` |
| `modules.py collisions` | **could not see the collision it was written for** — keyed its dict by filename stem and *assigned*, so duplicates overwrote each other |
| `host-fingerprint.nix` | "no attribute differs" for changes that moved the drvPath; it sampled names, not content |

**A summary line is not evidence.** `151 ok, 0 skipped` was true and useless —
the file it mishandled was counted OK.

**Test a checker against a case it should catch**, in the same commit. The
collision check was verified by renaming `boot-durandal.nix` back to `boot.nix`
and confirming the report.

Twice the defect was in the *reporting* rather than the logic, which is worse:
the tool destroys the evidence, then reports its absence. Prefer shapes that
cannot — `modules.py` maps name → *list* of paths, so a duplicate cannot be lost.

## 2. The repo is not the machine

The most expensive error of the port, made three times.

- Diagnosed impermanence as "inert since April". It was inert in *this branch*,
  which had never been deployed; `origin/main` carried the working version and
  that is what the machines ran.
- Wrote that tenacity had never had Home Manager, on the sibling handoff's
  authority. True of that branch, false of the machine.
- Several facts were simply not in the repo — that `root-blank` exists, that
  both disks are formatted alike. Each was one question to the person who owns
  the machines.

**Before claiming production impact, find out what is deployed.** When a claim
is about hardware, ask.

## 3. When a tool contradicts you, suspect yourself first

Twice I concluded a tool was broken and was wrong both times.

- `diff-config.sh` reported IDENTICAL against `HEAD~2`; an interleaved commit
  meant `HEAD~2` was not the commit I assumed.
- A `zsh -f -c` test appeared to show aliases do not chain. **zsh expands
  aliases at parse time**, so an alias defined and used in one command never
  could. Behind `eval`, both shells chain fine.

The second nearly cost three `eza` flags: the intuitive repair breaks the chain.

## 4. An unchanged fingerprint can mean the code is inert

Editing `boot.initrd.systemd.services.restore-root` left the initrd
byte-identical every time — not because the edits were equivalent, but because
that unit is only rendered under systemd stage 1, which was off. The service was
never built into anything.

**An identical fingerprint after a change you expected to matter is a signal to
investigate, not to relax.**

## 5. Writing a trap down does not stop you walking into it

`CLAUDE.md` gained a section on reading generated dotfiles. Within minutes I hit
both halves: queried `home.file.".zshrc"` (the attribute is `"./.zshrc"`, and a
wrong name returns **empty rather than erroring**), then found `.bashrc` empty
and briefly believed I had caused a regression — it has no `.text` at all, being
built from `.source`.

Both are now in `CLAUDE.md` *and* in `just dotfiles`, because the fix is a tool
that makes the mistake impossible, not a warning.

## 6. Bugs serialise

`SESSION-HANDOFF.md` §3 said four bugs had hidden behind one another on the
sibling branch. Four more did here, each invisible until the one before it
landed: `.blerc` declared twice → `boot` both a category and a module →
`jq`/`bitwarden` declaring nixos modules full of `home.packages` →
`programs.bash.blesh.enable`, an option Home Manager has never had.

**A defect count from static analysis is a lower bound.** The plan said eight;
it was twelve.

## 7. Cross-module side effects are invisible without a fingerprint

Removing fish — an unused shell — removed the man page index, because
`fish.nix:683` sets `programs.man.generateCaches = lib.mkDefault true` inside
`mkIf cfg.generateCompletions`. Nothing here mentions `programs.man`. `apropos`
would have stopped working with no visible cause.

`just diff` reported `homeFileHashes: removed '.manpath'` and that was the whole
thread. **Run it across any change that removes a module**, however unrelated.

The same tool caught a comment-only edit shipping fourteen lines into `~/.zshrc`:
`#` inside a `''` string is shell text, not a Nix comment.

## 8. A built-in option existing is not the same as it fitting

`documentation.man.generateCaches` exists and does not work here: `man-db.nix`
only maps `/run/current-system/sw/share/man`, so it would pay a full rebuild and
still not index `/etc/profiles/per-user/<user>/share/man`, where the packages
worth searching live.

**Read what an option generates, not what it is called.**

## 9. Caches in nix have three placements, and the default is the expensive one

| placement | cost | staleness |
|---|---|---|
| build time (`runCommand` over a `buildEnv`) | rebuilds when *any* input changes | never stale |
| activation (`home.activation`) | every switch, incrementally | current after each switch |
| timer (systemd user unit) | nothing at build or switch | bounded by the interval |

Both built-in man options take the first. `mandb` without `--create` *updates*
rather than rebuilds, which is what makes the other two viable.

## 10. Reading upstream source settled things guessing would have got wrong

- `flake-parts/extras/modules.nix:33` — `flake.modules` is
  `lazyAttrsOf (lazyAttrsOf deferredModule)` at the **top level**; the only
  `freeformType` is on `flake`. That is why 151 files could not keep
  `flake.modules` inside `perSystem`.
- `home-environment.nix:322` — `home.sessionPath` is `listOf str`, so duplicate
  definitions concatenate.
- Home Manager has **no blesh module**, so `programs.bash.blesh.enable` had
  never applied.
- `luksroot.nix`, `stage1Crypttab` — the crypttab line is `"${n} ${v.device} …"`,
  so `systemd-cryptsetup@<n>.service` is named after the **LUKS volume**, not the
  host. `systemd-cryptsetup@nire-durandal.service` named a unit that never
  existed; interpolating `networking.hostName` would produce another.

## 11. Read the links in a comment before deleting the code they annotate

I was about to replace a `requires`/`after` block whose lines carried a
systemd.unit(5) URL. Elly asked whether I had read it. I had not.

`Requires=` is an activation dependency, `After=` is ordering, neither implies
the other, and the manual says to pair them. Dropping `requires` would have
changed the failure mode from "does not run" to "runs and fails" — on the
service that deletes `/root`.

## 12. Verify the mechanism before betting a refactor on it

Before repairing `dirsAsCategory` rather than replacing it, the risky part —
reading `config.flake.modules.<class>` from a file that also *defines* an
attribute in it — was modelled with flake-parts' own option type and evaluated.
Cheap, and the difference between a recommendation and a guess.

## 13. Reversibility can stand in for a decision

Three times Elly declined a fork and asked for a documented escape hatch:
`dirsAsCategory.md`, `trailhead-home-manager-standalone.md`,
`lessons-learned-impermanence-stage1-migration.md`.
None had to be settled to make progress, and writing the reversal path while the
consequences are in hand is cheap. **Ask whether a close decision needs deciding
or documenting.**

## 14. Read the repo's own conventions before writing into it

`manconfig.nix` was written with a 25-line header and rejected for not matching
its neighbours. The repo had a style guide all along, four levels down beside
the package modules with nothing linking to it. `grep -ri 'style\|convention'
--include='*.md'` costs nothing.

## 15. Commit hygiene

- **A commit message must not describe state that does not exist.** One referred
  to a note not yet written; the next commit had to make it true.
- **Check what is staged before writing the message.** One commit swept 24 files
  in alongside a two-file rename; another quietly included a change the message
  never mentioned. Staging early — `git add` before `nix eval`, which flakes
  require — makes both easy to do by accident.
- **Order commits so each is green.** A checker fix and the refactor needing it
  landed checker-first; the other order leaves an intermediate commit where
  `just modules` fails. Verified in a throwaway worktree.
- **Git authorship does not say who wrote it.** Every commit here is authored by
  Elly, including ones written by an agent.

## 16. When the user redirects, the redirect carries information

Short corrections, each carrying a fact not available in the tree:

- *"see 08fcc74"* — settled the den-or-flake-parts question outright.
- *"I am ok with using persystem, just not den"* — my wording implied a verdict
  I did not mean.
- *"I am pretty sure the april commit was unused"* — reversed a wrong diagnosis;
  §2.
- *"jovian isn't tenacity's module, it's a generic handheld module"* — a framing
  error already propagated into two host configs.
- *"will that actually work"* — asked about a proposed *fix* rather than a
  diagnosis, and found a bug in it: a comment naming `@preLVMCommands@`, which
  stage 1 substitutes three passes after the one that inserts it.
- *"did you read the freedesktop links"* — §11.

**A correction phrased as a small clarification is often load-bearing.**

## 17. The record may already exist

The `dirsAsCategory` question was settled by finding the original exchange in a
previous session's transcript (`~/.claude/projects/*/[uuid].jsonl`), not by
re-deriving it. Transcript archaeology is available, and the user's own history
beats inference.

## 18. Say which rung you mean

*Evaluates*, *builds*, *runs* — each finds a different class of defect (§25), so
say which you have. Treat an undated "verified" in this repo as *evaluates*.

**And scope the claim.** For most of the port I wrote "nothing in this
repository has ever been built or switched", which is false and reached seven
files before Elly caught it. `origin/main` was deployed and already flake-parts;
what was unproven was this branch's 172 commits on top. "This has never worked"
and "this is a large untested delta on something that works" call for different
caution. An overclaim in the safe-sounding direction is still an overclaim.

There is a fourth rung between *evaluates* and *builds*: `nix build --dry-run`
gives the derivation plan — 711 to build, 2840 to fetch, and the fact that
`decky-loader` had nothing cached — without compiling anything. Real
information, and still not a build.

---

# From the first session on the hardware

## 19. The machine's own tools can lie about the machine

Confirming the disk matched `hardware-tenacity.nix` was a stop condition. The
obvious commands returned nonsense: `findmnt` said `/` was a tmpfs, `lsblk`
showed `enc` mounted at `/etc/xdg` and left every UUID column empty.

The shell runs in a mount namespace, and both tools report **that** namespace —
accurately, and about the wrong world. Read literally they say the disk does not
match the config, which would have meant regenerating a correct file.

Two sources are not rewritten, and both are unprivileged:

- `/proc/1/mountinfo` — PID 1's mount table
- `/dev/disk/by-uuid/` — udev's symlinks

Through those, every value matched. The same trap caught me again later via
`/etc`, which is also a namespace tmpfs here; store paths are the way out.

That output also carried the round's best evidence: `/` was **subvolid 607**
while neighbours sat at 257–265. Nothing but hundreds of recreations explains
that, which is the `/root` rollback demonstrably *running* — a stronger fact
than `root-blank` merely existing.

## 20. A pipeline reports the exit status of its last command

`just check 2>&1 | tail -60` exited 0 and I reported the check as passing. `just`
had exited 1; the failure was in the text `tail` printed, and I read past it
because the status said otherwise. `set -o pipefail`, or do not pipe.

**A status and the text above it are two claims, and when they disagree the text
is usually the honest one.**

## 21. An environment failure can wear a config failure's clothes

That same failure presented as a flake-parts evaluation trace — `while
evaluating the attribute 'root.result'` — which reads as a broken flake. Eight
lines lower: `HTTP error 401 … "Bad credentials"`. An expired GitHub token in
`~/.config/nix/nix.conf`, outside the repo, unrelated to any of the work.

**Read to the bottom of a nix trace before believing the top of it.** Nix puts
the innermost failure last; the frames above are the path taken, not the cause.

## 22. Name matching fails silently, and reads exactly like a real negative

§5 records this for `home.file` names. It recurred twice in output I had
generated myself:

- **The option and the package spell it differently.** I searched a build plan
  for `acpi_call` — the spelling used by `boot.extraModulePackages` — and got
  zero hits. The package is `acpi-call`. One keystroke from reporting a module
  the TDP control depends on as missing.
- **Zero in both columns can mean "already present".** `adjustor` appeared in
  neither the build nor the fetch list because it was already in the store. A
  dry-run enumerates *work*, not contents.

Same class, caught before shipping: `modules.py`'s pattern was `\w+`, which does
not match a hyphen. **Hyphens are legal in Nix identifiers**, so it would have
read `kde-base` as `kde` and reported a module created that hour as dead.

**Before believing a zero, show that the query can return non-zero.**

## 23. When a check fires on new work, fix its model before reaching for the flag

Splitting out `kde-base.nix` made `just modules` report it as an orphan.
`modules.py` has an `ORPHAN-OK` escape hatch for exactly that complaint.

Using it would have been wrong. The module *is* imported, through a `let`-bound
`config.flake.modules.nixos.kde-base` — a third import form the checker did not
model, and one **the repo already used**. The check was right to fire and wrong
about the reason; the flag would have silenced a true report and left the blind
spot for the next person.

**"This check is wrong" and "this check is incomplete" present identically and
call for opposite responses.** Per §1, the widened checker was then run against
a tree with a deliberately dead module, to confirm it still reports one.

## 24. Compare against what is deployed, not against the last commit

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

---

# From the first session where it actually ran

## 25. Running it is a rung of its own, and finds a different class

Switching put this branch on the hardware, and four things broke that neither
evaluation nor a successful build could see:

- VS Code launched pointed at an empty store directory as its extensions dir
- `ble-attach` ran ahead of seven other shell integrations
- `handheld-daemon` died on `import pkg_resources`
- suspend wrote a 2.3G hibernation image on every sleep

The daemon is the clean case: it evaluated, it *built*, and it failed on the
first line it executed, because a missing import is a runtime event.

## 26. "Did it work before?" is one command, and it beats reasoning

Twice I built a causal story the journal demolished. Vicinae crash-looping was
not what made the machine unusable — Elly had driven a rollback from a working
session. The stage-1 migration did not cause the suspend hang — hybrid-sleep had
been writing 2.1G images for months under scripted stage 1.

`journalctl --list-boots` plus one grep settled both, and a third question
(whether handheld-daemon had ever worked) in one line. Both times I ran it only
after being challenged.

**On a machine with persistent logs, "is this new?" is cheaper than any argument
about mechanism, and belongs before it.**

## 27. Check whether upstream already fixed it before writing the patch

`handheld-daemon` imports `pkg_resources`, which setuptools 83 removed. That got
a 45-line bespoke shim, and it worked, and it was the wrong artefact — upstream
had already replaced it with `importlib.metadata` in 4.1.12, in five lines.

Size is not the point: a backport of upstream's own change deletes cleanly when
nixpkgs catches up, where an invention has to be reconciled with whatever
upstream actually did. The same file settled a second question the first patch
got wrong — `pyproject.toml` says `where = ["src"]`, so the paths were `src/hhd/`.

**Read the project's current source and packaging metadata before writing
compatibility code.**

## 28. A guard keyed on a signal that never fires is worse than no guard

Moving the rollback to systemd stage 1 dropped the safety `postResumeCommands`
had for free: it ran *after* the resume attempt, so a hibernation resume skipped
the wipe. The name carried the guarantee.

The replacement, `ConditionKernelCommandLine = [ "!resume" ]`, cannot fire.
systemd does not need `resume=` on the command line —
`systemd-gpt-auto-generator` finds the swap partition by GPT type and sets
`/sys/power/resume` itself, which it had already done.

It was justified in a comment reading "tenacity has no swap", taken from
`swapDevices = [ ]`. The machine had 20G on `nvme0n1p6` the whole time. §2 and
§24, in the module that deletes `/root`, the same day as §24.

Hibernation is now off at the kernel level, which removes the hazard instead of
testing for it. **A condition is a claim about the world; check it fires on the
machine before trusting it to prevent something.**

## 29. Ordering fixes do not reach code that schedules itself later

`ble-attach` ran before seven integrations, so the fix was `mkOrder`. That was
correct and insufficient: one thing binding `Ctrl-R` was not in `.bashrc` at all.
`.blerc` registers it with `ble-import -d`, which loads "in idle time" — after
the whole file, `ble-attach` included.

Nothing done to a file's order controls something that has deferred itself out
of that file. The hook must attach to the deferred thing — here `ble-import -C`.

Second half, which the obvious fix gets wrong: **unbinding a key in a system
that replaced the underlying mechanism leaves it dead, not falling back.** ble.sh
replaces readline outright, so removing fzf's binding would not have revealed
atuin's underneath.

## 30. Removing a capability does not make its consumers degrade gracefully

Hibernation was disabled — `nohibernate`, plus `AllowHibernation`,
`AllowHybridSleep` and `AllowSuspendThenHibernate` off — to stop suspend writing
a 2.3G image and to close the hazard in §28. The comment justifying it said any
such request would "fall back to a plain s2idle suspend".

Nothing performs that fallback. KDE's PowerDevil had `SleepMode=2`
(`HybridSuspend`; the enum is `SuspendToRam = 1, HybridSuspend = 2,
SuspendThenHibernate = 3`). It asked logind for hybrid sleep, logind answered
`CanHybridSleep=no`, and the request was dropped. **Suspend stopped working
entirely**, and Elly found it, not me.

The capability was never gone: `CanSuspend` stayed `yes` and `/sys/power/state`
kept offering `freeze mem` throughout. Only the thing being *asked for* was
unavailable, and the caller had no second choice. The fix was one line of KDE
config, not a config change here.

Two rules out of it, and this is the second time in one session for the first
(§29, unbinding `Ctrl-R` under ble.sh leaves the key dead rather than revealing
what was underneath):

- **"It will fall back" is a claim about a specific consumer**, and consumers
  usually have exactly one plan. Name the consumer and check it.
- **When you turn something off, find what was asking for it.** A grep of the
  relevant `~/.config` would have shown `SleepMode=2` before the switch rather
  than after.

## 31. Count the thing you mean, and check the cleaner before declaring there is none

Found `/var/lib/systemd/coredump` at 1.1G and wrote a module capping it, on the
reasoning that "nothing ever clears it" and "the store only ever grows". Both
false, and the machine was right there to say so:

- systemd ships `d /var/lib/systemd/coredump 0755 root root 2w` in tmpfiles, and
  `systemd-tmpfiles-clean.timer` runs it daily. It had run ten minutes earlier.
- **Zero** files were older than fourteen days. Retention was working exactly as
  designed.

The second error was reading a number from the wrong tool. `coredumpctl list`
reported 76,171 entries; `find -type f` reported 1121 files. Those count
different things — the journal keeps a record after tmpfiles has vacuumed the
dump — so the "backlog" I thought was being reprocessed every boot was mostly
records whose files were already gone. drkonqi's "Unable to find file for pid
… expected at kcrash-metadata/…" is that, and is normal.

§22 is about not believing a zero without showing the query can return non-zero.
This is the same error with a large number: **a count is only evidence if you
know what it counts.** `coredumpctl list | wc -l` and `find | wc -l` differ by
70x here and neither is wrong.

The module survived, with its justification replaced. It is a rate ceiling —
bounding what a crash loop can spend between daily cleanups — not the retention
policy it claimed to be. And the cap was initially set *below* the 1.1G a real
bad fortnight had just produced, which would have discarded dumps during exactly
the incident they were wanted for. **A limit under the observed worst case is
not a safety measure.**

## 32. An auto-allocator that cannot see manual entries will collide with them

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

## 33. A removed option is not an ignored option, and defaults are worth reading

Three separate restatements went into one afternoon's libvirt module, and the
tree caught none of them:

- `virtualisation.libvirtd.qemu.ovmf` — every wiki page and blog post still
  tells you to set this. nixpkgs **removed** the submodule; all OVMF images
  QEMU distributes are now installed by default. It is not silently dropped:
  `libvirtd.nix` carries an assertion whose message is "the submodule has been
  removed", so writing it out of habit fails evaluation. `qemuOvmf` and
  `qemuOvmfPackage` are `mkRemovedOptionModule` alongside it.
- `virtualisation.libvirtd.allowedBridges` was written as `[ "virbr0" ]`. That
  is already its nixpkgs default, verbatim.
- `spice-gtk` was added to `environment.systemPackages` next to
  `virtualisation.spiceUSBRedirection.enable`, which installs `spice-gtk`
  itself for the polkit actions belonging to its setuid wrapper.

Only the first would have failed. The other two are the same class as the
`lib.mkIf (!pkgs.stdenv.isDarwin)` hand-restatement CLAUDE.md warns about under
"Platform support is derived": **config that agrees with the default is not
harmless, because it reads as a decision.** The duplicate `spice-gtk` was found
by evaluating the package-name list and noticing the same string twice —
`nix eval … environment.systemPackages --apply` with a filter, which takes
seconds and is worth doing after adding any module that installs things.

The general habit, since option churn in `virtualisation.*` is heavy: **read
the nixpkgs module, not the wiki.** The `mkRenamedOptionModule` /
`mkRemovedOptionModule` block near the top of one is a changelog of exactly the
options a stale guide will tell you to set.

## 34. The dangerous name collision is the one where both halves work

CLAUDE.md's `boot` story — the `nire/boot/` category and durandal's
`boot.nix` merging into one name — has an obvious tell: importing a bootloader
got you an impermanence rollback, which is startling enough to investigate.

Moving the VM modules into a category directory of their own set up the same
collision in a shape with no tell. The directory would have been
`nire/virtualization/`, so `dirsAsCategory` would declare
`flake.modules.nixos.virtualization`; the file inside it was `virtualization.nix`,
which declares `flake.modules.nixos.virtualization` from its own filename.
They **merge**. And both halves are libvirt config, so importing either name
still gets you working VMs, and the tree still evaluates, and `just diff` still
shows what you expected. Nothing would have looked wrong until someone imported
the category expecting the category.

Caught before it landed, by asking what the aggregate would be named rather
than by anything reporting it — `just modules` does detect it, but only once
the file exists and only if it is run. The file is `libvirt.nix` now, which is
the better name anyway.

**A merge is only visible when the two halves disagree.** When naming a module,
check what its directory is already going to declare — and prefer the specific
name for the file, leaving the general one to the category that hosts import.

## 35. "Enabled" is a claim about config, not about whether anything works

**Borrowed, not lived.** Everything above happened here. This one is a caveat
taken from someone else's bug report while enabling avahi and systemd-resolved
together (2026-08-21, `nire/system/networking/`), written down because the
shape is one this file already keeps hitting and because it is a live risk on
the next rebuild. Nothing on this fleet has demonstrated it yet — the config is
merged and unbuilt.

A NixOS Discourse thread reports `.local` names failing to resolve while
`resolvectl status` showed mDNS enabled **both globally and per-interface**.
Queries still timed out with "All attempts to contact name servers or networks
failed", while avahi resolved the same names on the same host. The suggested
per-link `nmcli` fix changed nothing, and the thread closed unresolved.

The trap is that mDNS is not a switch either daemon owns. It is a claim on UDP
port 5353, and only one listener receives the unicast replies. So a daemon can
be configured correctly, report itself enabled, and still answer nothing,
because another process holds the socket. **Neither daemon's status output
mentions the other.** `resolvectl status` will not tell you avahi has the port;
`avahi-daemon` logs about a competing stack, but only in its own journal.

Which makes "is it enabled?" the wrong question and "who holds 5353?" the right
one:

```sh
sudo ss -ulpn 'sport = :5353'      # who actually has the socket
resolvectl mdns                    # what resolved thinks, per link
journalctl -u avahi-daemon | grep -i "another\|stack"
```

Same family as §1 (a tool reporting success has not thereby been tested), §22
(a zero is not evidence until you show the query can return non-zero) and §31
(a count is only evidence if you know what it counts). The general form:

- **A configuration readout is not a functional test.** It reports intent, and
  intent is exactly what is not in question when two things contend.
- **When two components can claim one resource, neither one's view of itself
  is diagnostic.** Go look at the resource.

If `.local` misbehaves after the avahi/resolved rebuild, check the socket
before concluding the Nix config is wrong. The config was verified by value —
`nsswitch` ordering, `MulticastDNS = "no"`, the NetworkManager handover — and
none of that is evidence about a running daemon.
