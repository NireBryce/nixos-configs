# Lessons from the den → flake-parts port, 2026-08-08/09

Companion to `2026-08-08-PORT-PLAN-(COMPLETED).md` and `TENACITY-PLAN.md`, which
record *what* was done. This one records how the work went wrong in the doing,
because none of that is recoverable from the tree or the commits.

Written for the next instance. The technical traps live in `CLAUDE.md`; these
are about method.

---

## 1. A tool that reports success has not thereby been tested

Every tool written during this port was wrong on its first run. On its own that
is unremarkable — writing static analysis against a layout nobody has analysed
before is iteration, and iteration converging is the method working, not failing.

What is worth recording is the *shape* of the wrongness, because it was the same
every time: **all four reported success while being wrong.** None errored, none
warned, and three of the four would have passed review.

| tool | first-run defect | how it surfaced |
|---|---|---|
| `unwrap.py` (151 files) | silently skipped `sops.nix`, whose declaration ends in `=` with the body on the next line — would have dropped its `config` argument | printed a sample instead of trusting `151 ok, 0 skipped` |
| `modules.py orphans` | reported eight nested categories as dead, because `collectModules` recurses and a module in `langs` is also collected by `development` | the output was implausible on its face |
| `modules.py collisions` | **could not see the collision it was written for** — it keyed its own dict by filename stem and *assigned*, so two same-named files overwrote each other and it then found nothing | noticed while about to create exactly that collision, adding a second host's `hardware-configuration.nix` |
| `host-fingerprint.nix` | said "no attribute differs" for changes that moved the drvPath — it sampled home-file *names* not content, then filesystem names not options, then nothing of the initrd | tested against commits whose changes it should have caught |

So the discipline is what to take from this, not the count:

**A summary line is not evidence.** `151 ok, 0 skipped` was true and useless —
the file it mishandled was counted as OK.

**Test a checker against a case it should catch.** The collision check was
verified by renaming `boot-durandal.nix` back to `boot.nix`, confirming the
report, and restoring. A check nobody has seen fail is not known to work.

**Twice the defect was in the reporting rather than the logic**, which is the
worse kind: the tool destroys the evidence and then reports its absence. Prefer
a shape that cannot do that — `modules.py` now maps name → *list* of paths, so a
duplicate is structurally impossible to lose.

None of this argues for writing tools more carefully up front. It argues for
distrusting their first green result, which is cheap, and for building the
counter-example into the same commit.

## 2. The repo is not the machine

The most expensive error of the session, made three times.

- **I diagnosed impermanence as "inert since April" and said so plainly.** It was
  inert in *this branch's* code — which has never evaluated, never been built and
  never been deployed. `origin/main` still carries the working
  `postResumeCommands` version, and that is what the machines run. Elly said "I
  am pretty sure the april commit was unused" and was right. A defect on a branch
  nobody has switched to has not broken anything.
- **I wrote that tenacity had never had Home Manager**, on the sibling handoff's
  authority. That document says so accurately *about its own branch*, where only
  `elly@nire-durandal` survived the restructure. The machine had
  `nire-tenacity-hm-elly` with the identical config, on
  `origin/backup-before-flake-parts-happened`.
- **Several facts were simply not in the repo**: that `root-blank` exists, that
  both disks are formatted the same way, that the January hardware config is
  still accurate. Each was answered in one sentence by the person who owns the
  machines.

**Before claiming production impact, find out what is actually deployed** — here
`origin/main`, not the branch in front of you. And when a claim is about
hardware, ask. It is one question and the answer is authoritative.

## 3. When a tool contradicts you, suspect yourself first

Twice I concluded a tool was broken and was wrong both times.

- `diff-config.sh` reported IDENTICAL against `HEAD~2`, which I believed predated
  a config change. It did not — an interleaved commit meant `HEAD~2` was not the
  commit I assumed.
- A `zsh -f -c` test appeared to show aliases do not chain, which would have
  meant `ls` lost its eza flags. The test was invalid: **zsh expands aliases at
  parse time**, so an alias defined and used in the same command was never going
  to work. Behind `eval`, both zsh and bash chain fine.

Cost of getting the second wrong: I would have "fixed" `ls` by adding an explicit
alias, which *breaks* the chain and drops three flags. The intuitive repair was
the regression.

## 4. An unchanged fingerprint can mean the code is inert

The fingerprint exists to prove a refactor preserved behaviour — identical
drvPath, nothing moved, good. It also detects the opposite, and that turned out
to be the more valuable use.

Editing `boot.initrd.systemd.services.restore-root` left the initrd
**byte-identical every time**. Not because the edits were equivalent, but because
that unit is only rendered under systemd stage 1, which is off on both hosts, so
the service was never built into anything. Switching to `postResumeCommands`
moved the hash immediately.

**An identical fingerprint after a change you expected to matter is a signal to
investigate, not to relax.** That asymmetry is what diagnosed a module that had
been silently doing nothing.

## 5. Writing a trap down does not stop you walking into it

`CLAUDE.md` gained a section on reading generated dotfiles. Within minutes I hit
both halves: queried `home.file.".zshrc"` and got zero starship hits (the
attribute is `"./.zshrc"`, and a wrong name returns **empty rather than
erroring**), then found `.bashrc` empty too and briefly believed I had caused a
regression (it has no `.text` at all; it is built from `.source`).

Both are now in `CLAUDE.md` *and* in the `just dotfiles` recipe, because the right
fix is a tool that makes the mistake impossible, not a warning.

## 6. Bugs serialise, exactly as the handoff promised

`SESSION-HANDOFF.md` §3 said four bugs had hidden behind one another on the
sibling branch. Four more did here, each invisible until the phase before it
landed:

```
2c → .blerc declared twice; blesh.nix declared its module twice
2d → `boot` was both a category and a module name
2e → jq and bitwarden: nixos modules full of home-manager options
HM → programs.bash.blesh.enable, an option Home Manager has never had
```

**A defect count derived from static analysis is a lower bound.** The plan said
eight and it was twelve.

## 7. Cross-module side effects are invisible without a fingerprint

Removing fish — an unused shell — also removed the man page index, because
`fish.nix:683` sets `programs.man.generateCaches = lib.mkDefault true` inside
`mkIf cfg.generateCompletions`. Nothing in this repo mentions `programs.man`.
`apropos` would have stopped working with no visible cause.

`just diff` reported `homeFileHashes: removed '.manpath'` and that was the whole
thread. **Run it across any change that removes a module**, however unrelated.

The same tool caught a comment-only edit shipping fourteen lines into `~/.zshrc`:
`#` inside a `''` string is shell text, not a Nix comment.

## 8. A built-in option existing is not the same as it fitting

When the man index disappeared, `documentation.man.generateCaches` was the obvious
answer, and Elly's instinct to look for it was reasonable. It exists. It does not
work here, for a reason invisible from the option name or its description:
`man-db.nix` only ever maps `/run/current-system/sw/share/man`, so it would pay a
full rebuild and still not index `/etc/profiles/per-user/<user>/share/man`, where
the packages worth searching live.

**Read what an option generates, not what it is called.**

The consolation was in the same file: its last line is an unconditional
`MANDB_MAP … /var/cache/man/nixos`, a *mutable* cache that nothing in nixpkgs ever
populates. NixOS's own design assumes someone runs `mandb` out of band.

## 9. Caches in nix have three placements, and the default is the expensive one

| placement | cost | staleness |
|---|---|---|
| **build time** (`runCommand` over a `buildEnv` of packages) | rebuilds whenever *any* input package changes | never stale |
| **activation** (`home.activation` hook) | runs every switch, but incrementally | current after each switch |
| **timer** (systemd user unit) | nothing at build or switch | bounded by the interval |

Both built-in man options take the first. `mandb` without `--create` *updates*
rather than rebuilding, which is what makes the other two viable.

## 10. Reading upstream source settled things guessing would have got wrong

Every one of these changed a decision:

- `flake-parts/extras/modules.nix:33` — `flake.modules` is
  `lazyAttrsOf (lazyAttrsOf deferredModule)` at the **top level**; the only
  `freeformType` is on the `flake` option. That is why 151 files could not keep
  `flake.modules` inside `perSystem`.
- `home-environment.nix:626-628` — `home.shellAliases` feeds bash, zsh and fish.
- `home-environment.nix:322` — `home.sessionPath` is `listOf str`, so duplicate
  definitions concatenate.
- Home Manager has **no blesh module at all**, so `programs.bash.blesh.enable`
  had never applied.
- `man-db 2.13.1 --help` — `--user-db` exists and updates incrementally.
- `luksroot.nix`, `stage1Crypttab` — the initrd crypttab line is
  `"${n} ${v.device} …"`, so `systemd-cryptsetup@<n>.service` is named after the
  **LUKS volume**, not the host. `systemd-cryptsetup@nire-durandal.service` named
  a unit that never existed, and interpolating `networking.hostName` would have
  produced another one.
- `systemd/initrd.nix:450` — `postResumeCommands` is rejected *only when* stage 1
  is enabled, so it is correct on these hosts.

## 11. Read the links in a comment before deleting the code they annotate

I was about to replace a `requires`/`after` block whose lines carried a
systemd.unit(5) URL. Elly asked whether I had read it. I had not.

`Requires=` is an activation dependency, `After=` is purely ordering, neither
implies the other, and the manual says to pair them. Dropping `requires` would
have changed the failure mode from "does not run" to "runs and fails" — on the
service that deletes `/root`.

**A URL in a comment is usually there because somebody needed it.** Read it before
removing what it explains.

## 12. Verify the mechanism before betting a refactor on it

Before committing to repairing `dirsAsCategory` rather than replacing it, the
risky part — reading `config.flake.modules.<class>` from a file that also
*defines* an attribute in it — was modelled with flake-parts' own option type and
`apply`, and evaluated. It resolved cleanly. Cheap, and the difference between a
recommendation and a guess.

## 13. Reversibility can stand in for a decision

Three times Elly declined a fork and asked for a documented escape hatch instead:
`dirsAsCategory.md`, `home-manager-standalone.md`, `impermanence-stage1.md`.

None of those decisions had to be settled to make progress, and writing the
reversal path while the consequences are still in hand costs an hour where
re-deriving it later costs far more. **Ask whether a close decision needs
deciding or documenting.** All three open by saying they are not recommendations
to reverse, so nobody reads them as standing TODOs.

## 14. Read the repo's own conventions before writing into it

`manconfig.nix` was written with a 25-line header block and rejected for not
matching its neighbours. The repo has had a three-line style guide all along —
then at `modules/nirePackages/style-guide.md`, since moved to
`linux-flake/style-guide.md` — which I had not read after two days in the tree.
It was four levels down beside the package modules and nothing linked to it.
Neighbouring modules also put rationale *inside* the module body rather than in
a header.

`grep -ri 'style\|convention' --include='*.md'` costs nothing. Read the
neighbours before writing a new file, not after.

## 15. Commit hygiene, learned twice

- **A commit message must not describe state that does not exist.** One referred
  to a `PORT-PLAN.md` note not yet written; the next commit had to make it true.
- **Check what is staged before writing the message.** Twice, with different
  remedies: one commit swept 24 `dirsAsCategory` files in alongside a two-file
  rename and was split with `git reset --soft`; another quietly included a
  `blesh.nix` change the message never mentioned, fixed by amending.
- Staging early — `git add` before `nix eval`, which flakes require — makes both
  easy to do by accident.
- **Git authorship does not say who wrote it.** Every commit here is authored by
  Elly, including ones written by an agent. I said "you didn't add them" about a
  four-month-old commit; the honest statement is that it predates this session.

## 16. When the user redirects, the redirect carries information

Each of these was a short correction that redirected the work, usually because
it carried a fact not available anywhere in the tree:

- *"see 08fcc74"* — settled the entire den-or-flake-parts question. That commit
  is the migration in progress; no amount of reading the current tree said so.
- *"that's about a script to render them"* — I had found the wrong exchange in a
  prior transcript and was about to conclude from it.
- *"I am ok with using persystem, just not den"* — my wording implied a verdict I
  did not mean and that would have been wrong.
- *"make sure it follows the style of its neighbors"* — see §14.
- *"did you read the freedesktop links"* — see §11.
- *"I am pretty sure the april commit was unused"* — reversed a wrong diagnosis;
  see §2.
- *"jovian isn't tenacity's module, it's a generic handheld module"* — a framing
  error that had already propagated into two host configs and the plan.

A correction phrased as a small clarification is often load-bearing.

## 17. Decisions belong to the user, and the record may already exist

The `dirsAsCategory` question was settled by finding the original exchange in a
previous session's transcript (`~/.claude/projects/*/[uuid].jsonl`), not by
re-deriving it. Elly had approved the opt-in pattern on the sibling branch *and*
separately built categories here — contradictory until you find that the
roster-readability objection came **after** adoption and was answered with a
script rather than a reversion.

Transcript archaeology is available. The user's own history is a better source
than inference.

## 18. Honest reporting, specifically — and scope the claim

Nothing **on this branch** has been built or switched. Every "verified" claim
about this session's work means *evaluates and produces the expected
derivation*. The exception is `checks.<system>.module-tree`, which is static and
does build on darwin.

Say which you mean, every time — *evaluates*, *builds*, or *runs*.

**And get the scope right.** For most of this session I wrote "nothing in this
repository has ever been built or switched", which is false and was propagated
into seven files before Elly caught it. `origin/main` merged flake-parts in PRs
#28 and #29, already uses `flake-parts.lib.mkFlake`, and is what the machines
run. The architecture is deployed and proven; what is unproven is this branch's
172 commits on top of it.

That distinction is not pedantry — it changes the risk. "This has never worked
anywhere" and "this is a large untested delta on top of something that works"
call for different amounts of caution, and the second is the true one. An
overclaim in the safe-sounding direction is still an overclaim.
