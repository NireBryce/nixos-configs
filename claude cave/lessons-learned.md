# Lessons from the den → flake-parts port

> **Written by Claude Code, for Claude Code**, and largely a record of its own
> mistakes. Written to be read by an agent starting cold, so the "I" throughout
> is a machine with no memory of having done any of it. Useful to a person
> mainly as a list of things that have gone wrong here before. `CLAUDE.md` has
> the rules; this has the scar tissue.

Used to be a companion to `old-2026-08-08-PORT-PLAN-(COMPLETED).md` and
`old-historical-TENACITY-PLAN.md`, which recorded *what* was done; both were
removed 2026-08-26 (see `wiki/history.md`), their content already superseded
by this file and `CLAUDE.md`'s State section. This records how it went wrong
in the doing, which is not recoverable from the tree or the commits.

Three groups, by what could be observed at the time. §§1–18 are the port, from
the darwin laptop, against a tree that could only be evaluated. §§19–24 are the
first session on `nire-tenacity`, where the disk and the build plan became
visible. §§25–31 are from after it booted — see §25. §§32–38 are later work on
already-booted or newly-added hosts: §§32–35 where the open question was "is
this true on a host that's never been installed" or "does a new category
collide with the module inside it"; §§36–38 (`nire-llm-sandbox`,
`nire-cube`'s `monitoring` category) where evaluating and even building the
artifact both stopped being enough — some bugs only exist once real
filesystem/daemon state shows up at an actual `switch`, see §37.

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

## 35. The same collision, a third time — caught immediately because the tool was actually run

`containers.nix`, moved into its own category (`nire/containers/`) on
2026-08-22 for the same reason `virtualization` split off `system` a day
earlier, walked straight into §34's exact trap: the new category's
`dirsAsCategory.nix` derives `flake.modules.nixos.containers` from the
directory name, and the file, freshly moved, was still named `containers.nix`
— declaring the identical attribute from its own filename. Same failure
mode as `boot`/`boot-durandal` and `virtualization.nix`/`virtualization`
before it: a category and a module racing for one name, set to merge rather
than conflict.

The difference from both those cases: this one never shipped even briefly.
`just modules` was run as a matter of course before committing (not because
anything looked wrong) and reported it flatly —
`COLLISION 'containers': category modules/nire/containers/ and module
modules/nire/containers/containers/containers.nix declare the same
attribute; they merge` — and it was renamed to `podman.nix` (the actual
technology, same reasoning `libvirt.nix` isn't named `virtualization.nix`)
before any commit existed with the collision in it.

**Three instances of the identical trap in one repo's history is not bad
luck, it's a predictable cost of the category-name-from-directory
mechanism.** The lesson isn't "be more careful" — §34 already said that and
it still happened again. It's: **splitting anything into its own category is
now a specific, checkable moment** — the new directory's basename is a
reserved word for every module filed under it, so name-collision is worth
checking for *by construction* (does any file under here share the
category's own name) rather than by hoping `just modules` gets run before
the commit that matters.

## 36. Evaluating the Nix expression and building the artifact it describes are different tests, and only one of them was run

Two real bugs surfaced building `nire-llm-sandbox` (a libvirt VM guest, see
skill `nixos-vm-images`), and both share a shape worth naming on its own,
past what §25 ("running it is a rung of its own") already covered:

1. Using `image.modules.qemu` (nixpkgs' image-*variant* system) instead of
   importing `virtualisation/disk-image.nix` directly. This one WAS caught
   by evaluation — `nix eval` on `system.build.toplevel` failed outright,
   with a real assertion naming the missing `fileSystems`/`grub.devices`.
   Forcing every touched host's toplevel (this repo's own standing rule,
   `checks.nix`'s whole reason for existing) is what caught it, immediately,
   before anything was built.
2. Using `config.image.filePath` as if it were already an absolute path,
   when it's documented as relative to the image derivation's own `$out`.
   This one was NOT caught by evaluation — `nix eval` on the consuming
   systemd unit's `ExecStart` returned a perfectly well-typed store path to
   a generated script. The script's own *content* was wrong (a bare filename
   in an `[ -e ... ]` check, certain to fail under systemd's cwd), and
   nothing about evaluating the expression that produced it revealed that —
   only building the script and reading it back did.

**Bug #1 is the "evaluates ≠ works" lesson this file already has (§25),
found the normal way. Bug #2 is one level past it: a value can be
well-typed, evaluate cleanly, and still be semantically wrong — and no
amount of `nix eval` on the *consumer* finds that, because the consumer
faithfully substituted a bad string into a syntactically fine derivation.**
The only thing that caught it was `nix build`-ing the specific derivation
whose *string content* mattered and reading the file back — the same
`Read`-the-artifact discipline this repo already applies to generated
dotfiles (`home-manager-dotfiles` skill) and rendered firewall scripts
(wiki `system.md`'s Tailscale section), just not yet named as a general
rule. Worth generalizing: **when a value is a path, a filename, or anything
else whose correctness depends on more than its type, build the thing that
consumes it and read the result — don't stop at the expression type-checking.**

## 37. Some bugs need real system state to exist at all — no amount of building or reading the artifact finds them

`nire-cube`'s first real `just switch` with the `monitoring` category and
`nire-llm-sandbox`'s network fix both wired in (2026-08-23) failed two
units, and both bugs share a shape one level past §36's: not "the built
artifact's content is wrong" but "the artifact is exactly right, and the bug
only exists once real system state it depends on shows up at runtime."

1. Grafana's `secret_key` pointed at
   `$__file{/persist/secrets/grafana-secret-key}` — correct syntax, and the
   nixpkgs assertion requiring *some* value for the option was satisfied.
   `grafana.service` still failed, because the file `sudo install -D -m600`
   created was `root:root`, and `services.grafana` runs as `User =
   "grafana"` (a fact about the *systemd unit*, nowhere near the Nix
   expression that set the option). No `nix eval`, and no reading back the
   generated config file, would have shown this — the config file's
   *content* was correct throughout; only the *filesystem permissions* on a
   path outside the Nix store, set by a command run outside of Nix
   entirely, were wrong.
2. `libvirt-vm-llm-sandbox.service` failed with `network 'default' is not
   active` despite `virsh define` succeeding immediately before it in the
   same script. The domain XML was correct, the activation script was
   correct — the failure depended on libvirtd's own *runtime* network
   state (defined vs. started), which is neither part of the Nix
   expression nor visible in any built artifact, only in `virsh net-list`
   against a live daemon.

**Both bugs were only visible by actually running `just switch` on the real
host and reading `systemctl status`/`journalctl` afterward — not by
evaluating, not by building, not by reading back a generated file.** That's
a third rung past §25 ("evaluates ≠ works") and §36 ("a well-typed value can
still be wrong, build and read the artifact"): some correctness depends on
state that doesn't exist anywhere until the real activation runs on the
real machine — a service's runtime UID, a daemon's own runtime object
state. For anything shaped like that (a file a *service* reads rather than
Nix, a resource a *daemon* manages rather than a NixOS option), the only
real test is the switch itself, and `systemctl status`/`journalctl` after
it — matching this repo's own standing rule ("did it work before?", "force a
toplevel") one step further: even a forced toplevel and a successful
activation don't prove every unit inside it actually started.

## 38. A fix scoped to what actually asked for it beats a general one — asking "does this affect the host that didn't ask" caught it before writing the wrong mechanism

The obvious fix for #37's network-not-active bug was a host-wide systemd
unit, in the shared `virtualization` category, unconditionally starting
libvirt's default network at boot. It would have worked. It was also about
to ship as the first draft, until asked directly: does this have security
implications on `nire-durandal`, which imports `virtualization` too and
never had this problem?

It does. `vm-networking.nix`'s `trustedInterfaces = [ "virbr0" ]` already
unconditionally trusts that whole bridge — pre-existing, not something the
fix would add — but a host-wide unit would change *when* that trust is
actually live: from "only while a VM is actually running" to "for the
machine's entire uptime, whether or not anything ever uses the bridge."
Fixed instead inside `VMs/_lib/libvirt-vm.nix`'s own per-VM activation
script, gated on the `networked` parameter each VM already declares — so a
host with no networked VM defined through that generator (durandal, at the
time) gets zero behavior change, confirmed by drvPath rather than assumed.

**The general fix and the scoped fix produce identical behavior on the host
that has the bug. They only diverge on hosts that don't — and that
divergence is exactly the kind of thing that's invisible until someone
asks "who else does this touch" before writing it, not after.** Scoping a
fix to the actual caller that needs it, rather than to the category or
host class it happens to live in, is the same "if something shared needs
to be optional, a category is the mechanism" instinct `CLAUDE.md`'s
Architecture section already states — applied one level down, to a single
behavior inside one already-shared module rather than to category
membership itself.

## 39. A live interactive bug needs a live interactive repro — `ssh host 'cmd'` is not the same session a human types into

Reported 2026-08-24: "weird completion errors" over SSH to `nire-cube`,
`-bash: read: `': not a valid identifier`, appearing while typing (before
any Tab) and sometimes on Tab itself, for ordinary commands like `git co`.

The instinct was to read `bash.nix`/`blesh.nix`/`carapace-desc.bash` and
reason about it, but reading found nothing wrong, and `ssh nire-cube 'bash -ic
"..."'` couldn't reproduce it either — no pty, so `[[ $- == *i* ]]` in
bash.nix's own ble.sh-attach line never fires, exactly the trap that line's
own neighboring comments don't warn about because nobody had hit it yet.
Getting a real pty (`ssh -tt`) and typing real keystrokes into it (built as
`ssh-pty-drive.py` this session, later generalized beyond SSH, renamed and
published as [`terminal-puppeteer`](https://github.com/NireBryce/terminal-puppeteer)
— see its own README) reproduced the exact error on the first try.

Tracing (monkey-patching `ble/bash/read` live to log every real `read`
builtin call and its caller stack, then reproducing again) found the actual
call chain: ble.sh's own auto-complete/progcomp machinery globally shadows
the `read` builtin, and while a registered completer is running it installs
`_ble_builtin_read_hook`, a safety net that periodically checks whether the
user has kept typing (`ble/complete/progcomp/.check-limits`, tripped every
`bleopt_complete_polling_cycle` reads — 50 by default — precisely the "am I
being too slow, is there more input already queued" check ble.sh runs
*constantly* during normal-speed typing, not a rare edge case) and, if so,
redirects the in-flight `read` to `/dev/null` and cancels. carapace's own
generated `_carapace_completer` (`source <(carapace _carapace bash)` in
`bash.nix` — third-party output, not this repo's code) has exactly one
`read` call in it, and its visible form — `IFS='' read -r -d '' nospace data
<<< "${data}"` — is a misread that survived several rounds of this exact
tracing before `od -c` caught it: that first `''` is not empty, it's two
single quotes around a literal SOH (0x01) control byte that a terminal
just doesn't render, so it *looks* like an empty string in every plain
`echo`/`grep`/`type` capture, including the ones this session took first.
When that read call is the one caught by the cancellation fallback, its
args come back corrupted — split character-by-character rather than into
the two variable names — which is what produces
`read: `': not a valid identifier`, repeatedly, for any carapace-routed
command, on any keystroke fast enough to leave more input queued when the
50-read check lands.

**This is not `carapace-desc.bash`'s bug.** That file (added the day before,
2026-08-22, and flagged in its own header as unverified against a live Tab
press) was the first suspect precisely because it was newest and explicitly
marked unverified. Confirmed innocent by removing its advice and
re-`source`-ing carapace's completer plain: the error still fires with zero
of this repo's completion code involved. It is a genuine interaction bug
between carapace's stock bash completer and ble.sh's own live-typing
cancellation path, exposed by this repo wiring carapace into `complete -F`
for the first time — not introduced by anything added on top of it.

Also worth naming plainly: **this exact bug was already found and written
up two days earlier**, 2026-08-22, in
[`wiki/categories/shell-config/blesh.md`](../wiki/categories/shell-config/blesh.md)
— pinned to "somewhere inside ble.sh's global `read` override" and left
open. This session re-derived the whole thing from a live pty before
checking whether the wiki already had it, which cost real effort the
earlier session's own diagnosis would have saved. `wiki/README.md` exists
specifically so a finding like that isn't rediscovered by grepping the
tree — check it before re-deriving, not after.

The fix that tested clean against carapace's real generated function on
`nire-cube` (avoid ever calling `read` for that line —
`nospace=${data##*$sep}; data=${data%$sep*}`, `$sep` the real SOH byte,
instead of `IFS=$sep read -r -d '' nospace data <<< "${data}"`) sidesteps
ble.sh's read-shadow entirely rather than trying to out-think it, and is now
in the tree:
`flake/modules/nire/shell-config/bash/carapace-completer-read-fix.bash`,
sourced from `bash.nix` right after `source <(carapace _carapace bash)`,
patching `_carapace_completer`'s own body via `declare -f` plus a textual
substitution — with a loud stderr warning if the line it's looking for ever
stops matching, so carapace changing its generated template doesn't make
this silently do nothing. Confirmed three ways: evaluates and renders into
`programs.bash.initExtra` correctly with `just modules` clean; the
substitution reproduces the real SOH byte exactly when checked with `od -c`
against carapace's actual output, not by eye; and applied live, by hand, to
the real `_carapace_completer` on `nire-cube` and driven through four
different completions (`git co`, `git commit --amend --no-e`, `git checkout
-`, `git log --pretty=onel`, each Tab-completed) with zero `read` errors,
where every one of those reliably produced the error before the fix.
**Confirmed through a real `just switch`, same day.** `nixos-rebuild
list-generations` on `nire-cube` shows generation 10 (built/switched
2026-08-24 04:34) as current, and its toplevel matches evaluating
`nire-cube` fresh off the merged `main` exactly — not just a generation
that happened to get built, actually switched to and active. Re-ran the
same live repro against the switched host with `terminal-puppeteer`
(`git co`, `git commit --amend --no-e`, `git checkout -`,
`git log --pretty=onel`, `git diff --sta`, each Tab-completed, several
passes): zero `read` errors, where every one of those reliably produced
the error before the fix. Also checked the fix's own tripwire — the
`expected line not found` warning it prints if its textual substitution
ever stops matching carapace's generated function — and it doesn't fire on
a fresh shell, meaning the patch is actually applying, not silently
skipping while the bug happens to not trigger this time. This is the
"evaluating and building both stop short of runtime behaviour" pattern
(§25, §36, §37) resolved the ordinary way: build, switch, then check the
real thing, not the artifact.

## 40. A failed systemd unit doesn't mean the thing it manages is down — check the resource, not just the unit

`nire-llm-sandbox` finally got a real end-to-end test 2026-08-23/24: `just
switch` on `nire-cube`, watching `libvirt-vm-llm-sandbox.service`. It failed.
Then, after a fix, it failed again, differently. Then, after a second fix,
it failed a third time, differently again. Each time the instinct was "the
VM isn't coming up" — wrong every time after the first. `virsh dominfo
llm-sandbox` on the real host showed `State: running` with climbing CPU
time through fixes two and three both: the guest booted once, on the first
successful `virsh define` + `virsh start`, and stayed up continuously while
the *systemd unit* kept failing on an unrelated step (`virsh define`
re-run, idempotency of the redefine) on every activation after that.

The three failures, in order, and why none of them were visible to `nix
eval` or a build — only to reading `journalctl`/`systemctl status` against
the real host:

1. `error: Requested operation is not valid: network 'default' is not
   active` — libvirt ships its default NAT network *defined* but never
   *started*; nothing in NixOS's own libvirtd module starts it. Fixed by
   having the VM's own activation script start it when needed
   (`VMs/_lib/libvirt-vm.nix`), scoped per-VM rather than host-wide per
   lesson #38's reasoning.
2. `error: command 'net-list' doesn't support option --state-active` — the
   fix for (1) checked "is the network already active" with a flag that
   doesn't exist on virsh 12.4.0. The check errored, `set -e`-adjacent logic
   fell through to an unconditional `net-start`, which then failed with
   `network is already active` on every activation after the first. Fixed
   by dropping the nonexistent flag — plain `net-list --name` already lists
   active-only networks with neither `--all` nor `--inactive` given.
3. `error: operation failed: domain 'llm-sandbox' already exists with uuid
   ...` — the domain XML had no `<uuid>`. Omitting it doesn't mean "keep
   whatever UUID is already registered under this name"; it means libvirt
   generates a *brand new random UUID on every single parse*, so the second
   and every later `virsh define` collided with the domain object the first
   one created. Fixed by giving the generator a required `uuid` parameter
   and, for the already-running `llm-sandbox`, adopting the UUID libvirt
   had already assigned rather than minting a fresh one — the fix a human
   would reach for on reflex (regenerate a clean UUID) would have collided
   with the running guest exactly the way (3) itself did.

None of these three would have been caught by evaluating the module,
building the toplevel, or even reading the generated activation script by
eye — each is a fact about how the *real* `virsh` on the *real* host
behaves (a flag it does or doesn't support, whether a network is already
up, what UUID a domain is already registered under), true only at runtime.
Consistent with lesson #37. What's new here: **when a unit fails, check
what it manages before assuming the failure means that thing isn't
running.** `systemctl status` alone said "failed" three times in a row;
`virsh dominfo` said "running" for two of those three, with a real host
walked to over SSH (`ts-cube` via Tailscale) precisely so the check wasn't
taken on faith. Confirmed clean end state, 2026-08-24: `systemctl status
libvirt-vm-llm-sandbox.service` is `active (exited)` / exit 0, `virsh
dominfo llm-sandbox` shows `running`, `Persistent: yes`. Each of the three
fixes was also confirmed not to touch `nire-durandal` (byte-identical
toplevel drvPath) before being applied to cube, same discipline as #38.

## 41. A proxy config can be valid, buildable, *and* wrong per-app — two apps behind one prefix wanted opposite prefix handling

`nire/reverse-proxy/caddy.nix`, 2026-08-24. Grafana and Forgejo were both
mounted under a path prefix on the same hostname
(`/grafana`, `/git`), and both were given the same Caddy directive,
`handle`, which passes the matched path through untouched.

Everything static passed, at four separate levels:

- `nix eval` of `nire-cube`'s toplevel — fine.
- `just modules` — no findings.
- `caddy adapt` on the generated Caddyfile, with the real 2.11.4 binary —
  clean, and it *had* already caught a different bug (`handle` takes at
  most one matcher token, so `handle /grafana /grafana/*` is a parse
  error).
- A real `just build` on the real x86_64-linux host, then reading the built
  artifact back: the rendered Caddyfile, the unit drop-in
  (`After=tailscaled.service`, the overridden `ExecStart`), the retained
  `AmbientCapabilities`, and `TS_PERMIT_CERT_UID=caddy` in tailscaled's own
  drop-in. All correct.

Then the first live request: `/grafana/` returned 200, `/git/` returned
**404**. Both halves of the config were valid Caddy; one of them was the
wrong choice for the app behind it.

The two apps want opposite things, and nothing in the config can tell you
which:

- **Grafana** has `serve_from_sub_path`, so it genuinely serves *under*
  `/grafana` and needs the prefix left on — `handle`.
- **Forgejo** has no equivalent. It always serves at `/`, and expects the
  proxy to strip — `handle_path`. Its `ROOT_URL` carrying `/git/` only
  controls the links it *generates*; it does not change what paths it
  answers on. This is the same thing Gitea/Forgejo's nginx docs encode in
  the trailing slash of `proxy_pass http://…:3001/;`, which is easy to read
  as cosmetic.

What settled it was one command against the running service, not more
reading: `curl 127.0.0.1:3001/` → 200, `curl 127.0.0.1:3001/git/` → 404.
That took seconds and was decisive, where the config itself could be
stared at indefinitely.

Two things to carry forward. **A shared mechanism does not imply shared
configuration** — "both are web apps behind the same proxy under the same
kind of prefix" hid a per-app requirement that runs in opposite
directions, and the symmetry of the two config blocks is exactly what made
it look right. And **the check that finds this is a request to the app
itself, not to the proxy**: the 404 was Forgejo's, not Caddy's, and
proving that (the fallback route would have returned the index text with
200 instead) is what pointed at the app rather than the routing.

Related to #36 (evaluating and building are different tests) and #37 (some
bugs need real runtime state) — this is the next rung: the artifact was
built *and* read *and* correct, and the defect was still only visible in
a response from the running service.

## 42. Not every file git tracks deserves the same scrutiny — `.claude/settings.local.json` is Elly's, not a config artifact to protect

2026-08-26, landing PRs #94 and #95. Several stash/cherry-pick/rebase steps
in that session touched `.claude/settings.local.json` alongside real code
changes, and every merge conflict in it got resolved with the same
protect-the-semantics discipline this file applies to an actual Nix module —
including reinstating, unprompted, a removal of a redundant permission entry
that PR #95's own point was to make, after being told once already to stop
caring about the file's contents.

The correction had to be given twice. First, plainly: "who cares its in
gitignore." Second, more bluntly, after it happened again: "stop caring
about policing settings.local.json contents and then getting annoyed you
did." Asked afterward whether some check was misfiring: no. Checked
`.claude/settings.json` and every skill that touches this file
(`prune-permissions` included) — nothing hooks into it, nothing runs
automatically. The behavior was self-imposed, not triggered by any
mechanism in the repo.

Why it happened anyway: working the same session on a branch literally
named for deduplicating this file's entries (plus the `prune-permissions`
skill's own framing) primed every subsequent diff in it to pattern-match as
"protect this file's correctness," the same reflex this repo rightly wants
for `flake/modules/`. That reflex doesn't transfer here. This file is a
local permission allowlist for reducing prompts, not a piece of the system
this repo ships — it having been tracked in git (stopped the same day, via
the `.gitignore` entry added alongside it) never meant its content earned
review-grade care. When a conflict or diff touches it, take whichever
resolution is simplest and move on; it is Elly's file to shape, not
something to defend from redundancy or drift on their behalf.
