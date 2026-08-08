# Handoff: what isn't in the tree

Companion to `SESSION-CHANGES.md` (which commit did what, and where the same
bugs still live on `flake-parts-consolidation`). This one answers only what you
cannot reconstruct by reading code. Written 2026-08-07, on the `flake-parts`
branch — read both from anywhere with:

```sh
git show flake-parts:SESSION-HANDOFF.md
git show flake-parts:SESSION-CHANGES.md
```

## Read first, in case you read nothing else

1. **`perSystem` is core flake-parts, not a den or flake-aspects concept.** An
   instance on the other branch said otherwise. It is declared in
   `flake-parts/modules/perSystem.nix` and loaded from `all-modules.nix:16`,
   next to `withSystem.nix`. Believing otherwise would distort the den decision
   in §1, which is the decision this document exists to inform.
2. **I never evaluated den or flake-aspects.** They were gone before I started.
   Nothing here is evidence against them. See §1.
3. **Two bugs that made tenacity unbuildable here are still live on
   `flake-parts-consolidation`**, both in
   `linux-flake/modules/nire/desktop-env/jovian/jovian.nix`: a reference to
   `adjustor`, removed from nixpkgs, and `inputs.jovian.decky-loader`, which
   that flake does not expose. Two more are live in its
   `shell-config/{zsh,bash}` — see §9 and `SESSION-CHANGES.md` part 1.
4. **Nothing in this session was ever built or switched**, on any host. See §9.

---

## 1. den / flake-aspects — I have no opinion, and you should not infer one

**They were already gone before I started. I never evaluated them, never tried
them, and never rejected them.** Nothing in this session is evidence for or
against den.

What was actually true at session start:

- `linux-flake/flake.nix` lines 34-36 had `den`, `flake-aspects` and
  `flake-file` **commented out** as inputs. They are still commented out — I
  never touched those lines.
- `grep -rn '\bden\.' linux-flake/modules` returned nothing, and still does.
- The migration *off* den happened before me, in commits like `67a1284` ("I
  have re-wrapped most of the modules") and `1560992`.
- I deleted `scripts/swap-headers.{sh,py}` and `find-headers.sh` in `4aaeefc`.
  Those were the tools that **performed** that migration — they transform
  den-wrapped files into flat modules. I deleted them because den was already
  absent so they had nothing left to operate on, and `find-headers.sh`
  hardcoded `/Users/elly/nixos/linux-flake/configs/home-manager/user-elly`, a
  path deleted in `8244eb9`. **That deletion is not a verdict on den.** If you
  port den back, recover them with
  `git show 4aaeefc^:linux-flake/scripts/swap-headers.sh`.

**Correction you need before deciding.** You reported another instance saying
`perSystem` is a den or flake-aspects concept. That is wrong, and it is the
kind of wrong that would distort this decision. `perSystem` is core
flake-parts: declared in `flake-parts/modules/perSystem.nix`, loaded from
`all-modules.nix:16`, alongside `withSystem.nix`. It has no relationship to
den. `withSystem` is likewise core (`modules/withSystem.nix`, three lines:
`withSystem = system: f: f (getSystem system).allModuleArgs`).

So the den question is genuinely open and orthogonal to everything I did. The
pattern this branch uses — one file per module, each opting itself into an
aggregate — is plain flake-parts plus `import-tree`, with no den layer. That is
a data point about *feasibility without den*, not an argument against it.

---

## 2. Dead ends, with the actual symptom

**Home Manager: standalone vs NixOS module.** Not a failure, a fork in the
road. Both were wired up simultaneously and only one did anything: the NixOS
side imported `home-manager.nixosModules.home-manager` and then never set
`home-manager.users.*`, so it was inert; everything real came from
`homeConfigurations`, which existed only for durandal. Tenacity therefore had
no home config at all. Elly chose integrated. Consequences that bit:

- `useGlobalPkgs = true` makes HM **reject** `nixpkgs.*` options outright. I
  had to delete `nixpkgs.config` from `elly-nix-settings`. That silently drops
  the `allowUnfreePredicate` workaround for HM issue #2942 — if unfree
  packages start failing on that branch, this is why.
- HM's own source handles the standalone→module migration: with
  `useUserPackages`, its `installPackages` step reduces to
  `nixProfileRemove home-manager-path`, so the old user profile cleans itself
  up. I originally told Elly they'd have to expire it manually; that was wrong.
- `home.profileDirectory` moves from `~/.nix-profile` to
  `/etc/profiles/per-user/<user>`.
- Activation becomes a systemd unit, so its `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd, and `QT_QPA_PLATFORM=offscreen`.
  Anything assuming a login shell will not see it.

**The two `config`s. This is the one that will bite you.** Every file has an
outer flake-parts scope and an inner NixOS/HM module, both named `config`. A
module written as a bare attrset has *no* inner scope, so `config` in it still
means the flake-parts one. Adding an argument list to reach the NixOS `config`
silently repoints every existing `config` in that module:

```nix
flake.modules.nixos.home-manager = {                      # bare attrset
    home-manager.users.elly = config.flake.modules.homeManager.ellyHomeManager;
};                                                        # ^ flake-parts config

flake.modules.nixos.home-manager = { config, ... }: {     # now shadowed
    home-manager.users.${config.nire.primaryUser} = ...;  # NixOS config
    # config.flake.modules.* no longer resolves here
};
```

Fix is to bind what you need from the outer scope in a `let` above the
declaration. `modules/nire/home-manager/enable-home-manager.nix` does exactly
this and says so.

**perSystem `pkgs` for hosts.** I considered `nixpkgs.pkgs = pkgs` via
`withSystem` and rejected it by reading, not by hitting the failure — stating
that plainly because it is an inference, not an observation. perSystem's `pkgs`
defaults to `inputs.nixpkgs.legacyPackages.${system}`, which has no
`nixpkgs.config` applied, so `allowUnfree` would be lost and this config
installs plenty of unfree packages. `nixosSystem` therefore builds its own pkgs
from the host's own `nixpkgs.config`, at the cost of a second instantiation.

**powerlevel10k, done then undone.** I made p10k load correctly (`aa38936`),
then found starship already won: in the generated `.zshrc` the theme was at 289
and its settings at 330-1991, but `programs.starship.enableZshIntegration`
emitted its init at 2025 and ran last. The prompt had been starship all along
while 1,660 lines of p10k config did nothing. Elly chose starship for all
shells and it was removed again (`b939b62`). `.zshrc` went 106,449 → 18,780
bytes. **If consolidation has both, it has the same silent conflict.**

**Reachability with segment-scoped edges → 119 false orphans.** In
`scripts/modules.py`, `tree` attributes references to the declaration whose
text region they sit in. Reusing that for `orphans` reported 119 of 160 modules
dead, because `enable-home-manager.nix` binds `ellyHomeManager` in a `let`
*above* the first declaration — no segment owns it, the edge vanishes, and the
whole homeManager tree detaches. `orphans` uses file-level edges instead, where
no edge can be lost. Do not "simplify" those two to share one edge model.

**`ble-import` without the `.bash` extension.** I wrote the imports without it;
reading `ble/util/import/search` in the blesh source showed the extension
fallback applies only to *relative* module names, while absolute paths are
tested with `[[ -e $ret ]]` directly. All five imports would have silently
failed with no error at build time. Caught by reading source, not by any tool.

**Smaller ones, each real:**
- `nix eval` returning `[ ]` for a check I had just written — flakes ignore
  untracked files. `git add` before evaluating. This cost time twice.
- `${terminfo[khome]}` written inside a Nix `''` string is interpolation, not
  text. Evaluation error; caught by the editor's linter.
- `.blerc` generated twice: two modules declared `home.file.".blerc".text`, and
  that option is `types.lines`, which **concatenates** rather than overrides.
  Every `ble-import` ran twice.
- `just` runs recipes from the justfile directory, so `.#` resolved against the
  repo root, which has no `flake.nix`. And stdin under `just` is neither a tty
  nor closed, so a `[[ -t 0 ]]` check either read nothing or hung on `cat`.
- An interactive `cp` prompt silently declined to restore a file mid-test,
  leaving a temporary edit in place. Caught by `git status`.

---

## 3. The two bugs in `checks.nix` — what they looked like

Both had been sitting in a **branch that could not evaluate at all**. Not one
host, not one output: `nix eval .#nixosConfigurations.<any>` failed.

**Raw NixOS module in the import-tree path.**

```
… while evaluating the module argument `modulesPath' in ".../tenacity/hardware-configuration.nix":
… noting that argument `modulesPath` is not externally provided, so querying `_module.args` instead
… if you get an infinite recursion here, you probably reference `config` in `imports`
error: infinite recursion encountered
```

Time to find: about one command, because the trace named the file. What makes
it dangerous is not difficulty, it is that **the error blames the wrong thing**
— it points at `modulesPath` and `_module.args` and suggests you referenced
`config` in `imports`, none of which is the actual cause. The cause is that
`import-tree` handed flake-parts a plain NixOS module.

The real cost was elapsed time, not debugging time: introduced in `9fa44b2` (a
Claude Code session, which added the file as 95 lines of unwrapped
`nixos-generate-config` output) and fixed in `922289e` four days later. Nobody
evaluated in between. `scripts/new-host-hardware.sh` exists to make this
unrepeatable.

**Invalid module class.**

```
error: The module `…/flake.nix#modules.jovian.wm-jovian` (class: "jovian")
cannot be imported into a module evaluation that expects class "nixos".
```

Only visible **after** fixing the first one — they were serialized. flake-parts
stamps the outer attribute name onto the module as `_class` verbatim and
validates nothing, so `flake.modules.jovian.foo` declares successfully and
fails much later, at the import site. The one mercy: it also sets
`_file = "<flake>#modules.<class>.<name>"`, which is the string in that error,
so it names its own declaration site. Only `nixos`, `homeManager`, `flake` and
`generic` mean anything.

**The lesson is the serialization, not either bug.** Behind those two were two
more, invisible until `checks` forced a host toplevel: `adjustor` removed from
nixpkgs, and `inputs.jovian.decky-loader` which does not exist. Four bugs, each
hiding the next, on a branch where `networking.hostName` evaluated perfectly
happily. **Evaluating a cheap attribute proves nothing.** That is the entire
argument for `checks.nix` forcing `system.build.toplevel`.

---

## 4. Load-bearing constraints

Things that look arbitrary and are not:

- **`pkgs` is deliberately not taken from perSystem** for hosts — see §2.
  Changing `hosts.nix` to share the perSystem instance loses `allowUnfree`.
- **`treefmt.flakeCheck = false`** because the tree is not formatted. Set it
  true and `nix flake check` fails immediately. Separately, running `nix fmt`
  reformats every file and flattens the aligned-`=` style, which is deliberate,
  not accidental. Reformat as its own commit or not at all.
- **Ordering in generated shell rc files.** HM emits `initContent` `mkBefore`,
  then `mkOrder 550`, then `programs.zsh.plugins`, then unordered
  `initContent`. Anything that must run *after* a plugin cannot sit at 550 —
  that is why the p10k settings block had to move. And **later definitions
  win**, which is why four hand-written aliases had no effect and why starship
  overrode p10k.
- **`home.file.<n>.text` is `types.lines`** — concatenates, never overrides.
  One owning module per generated file.
- **Absolute `ble-import` paths need `.bash`.** Relative module names do not.
- **`git add` before `nix eval`**, always.
- **`checks` is filtered by system**, so on darwin only the orphan check and
  the formatter run. The host toplevel checks have never executed anywhere.
- **`withSystem` requires the system to be in `systems`.**
- **`config.flake.modules.…` over `self.modules.…`** inside flake modules —
  same data, shorter dependency path, avoids a class of recursion.
- **The `nire.primaryUser` comment deliberately contains the literal string
  `users.users.elly`.** It is the only place that string now appears, so
  grepping the old form lands somewhere instead of nowhere. Do not "tidy" it.
- **`modules.py` needs two edge models** — see §2.

---

## 5. Ordering, if redoing this from a den-based tree

Each step's precondition is that the previous one holds. The sequence matters
because most of it cannot be verified until the flake evaluates.

1. **Make the flake evaluate.** Precondition: every `.nix` under the
   import-tree path is a flake-parts module, not a bare NixOS/HM module.
   Nothing below is checkable until this is true.
2. **Add `checks` forcing each host's `system.build.toplevel`.** Precondition:
   step 1. This is what surfaces the content bugs; without it you are testing
   nothing. Expect it to fail immediately and reveal real breakage.
3. **Fix whatever step 2 exposes** — for us, `adjustor` and `decky-loader`.
   Precondition: you can now see failures at all.
4. **Establish a fingerprint before touching structure.** Capture host
   `toplevel.drvPath` and an attribute sample. `scripts/diff-config.sh` and
   `host-fingerprint.nix` do this. Precondition: steps 1-3, i.e. a *green*
   baseline. A fingerprint of a broken tree is worthless.
5. **Decide Home Manager standalone vs NixOS-integrated.** Precondition: none
   technically, but do it before step 6 — both touch
   `enable-home-manager.nix`, and the `useGlobalPkgs` fallout changes what
   `nixpkgs.config` may exist.
6. **Structural refactors** — aggregates/roles, then the primary-user option.
   Precondition: step 4, so each one can be shown behaviour-preserving.
   Expect drvPath to change from import reordering alone; compare the package
   *set*, not the hash.
7. **Shell config.** Precondition: none of the above, genuinely independent —
   but it is high-churn and noisy, so doing it earlier drowns the structural
   diffs.
8. **Scripts, orphan check, docs.** Precondition: the layout has stopped
   moving, since `add-pkg.sh` and `modules.py` encode path and aggregate names.

The thing I would do differently: **step 2 before anything else.** Four bugs
were hiding behind an evaluation that "worked".

---

## 6. The opt-in pattern: why, and how it fails

*The mechanism is in `CLAUDE.md` and `linux-flake/flake-parts-reference.md`.
This is only the part that is not in either: why it is shaped this way, what it
costs, and every way I saw it go wrong.*

**What it replaced.** Two hosts each carried a hand-written list of ~25 module
names overlapping in ~19, so adding a module meant editing every host that
wanted it. The Home Manager side was worse: `ellyHomeManager` was
`builtins.attrValues (builtins.removeAttrs self.modules.homeManager
[ "ellyHomeManager" ])` — "import everything except myself" — carrying a TODO
saying the exclusion list was not a workable solution. Anything that should not
apply everywhere would have had to be excluded by hand, there.

**I verified the mechanism before committing to it**, rather than trusting that
`deferredModule` merges. A throwaway `mkFlake` with two separate modules each
setting `flake.modules.nixos.workstation.imports` produced a config carrying
both definitions. Worth redoing on a den-based tree before betting a refactor
on it, since den may wrap or re-key these.

**Failure mode 1 — the silent one, and the reason `checks.nix` exists.** Omit
the opt-in line and *nothing happens*. The module is valid Nix, evaluates
cleanly, and installs nothing. There is no error, ever, and no evaluation can
produce one, because from the evaluator's point of view nothing is wrong. This
is the pattern's single real cost and it is why `scripts/modules.py orphans`
runs as a flake check. On any tree using this pattern, port that check early.

**Failure mode 2 — collisions merge instead of erroring.** Module names share
one namespace per class. Two files declaring `flake.modules.homeManager.foo`
do not conflict; they merge into one module. So a copy-paste that forgets to
rename gives you a package module that silently also carries someone else's
config. `scripts/add-pkg.sh` refuses when the name already exists, which is the
only reason that guard is in there.

**Failure mode 3 — reaching the inner `config` breaks the outer one.** Covered
in §2, but it bites specifically here: the opt-in line uses the *flake-parts*
`config`, and the module body often wants the *NixOS* one. Adding `{ config,
... }:` to the body repoints both.

**Failure mode 4 — `let`-bound references escape per-declaration analysis.** A
reference bound in a `let` above the first declaration belongs to no
declaration. Only matters for tooling, but it is what produced the 119 false
orphans in §2.

**A layering choice that looks redundant and is not.** Package modules opt into
`pkgs-cli`/`pkgs-gui`/`pkgs-linux-utils`, and those three opt into
`ellyHomeManager` — rather than each package opting straight into
`ellyHomeManager`. The indirection exists so a host role can later take some
groups and not others without touching 104 files. Elly explicitly deferred that
split (see §7), so today the indirection buys nothing visible. Do not collapse
it.

**The accepted cost.** No file lists an aggregate's roster any more; there is no
`desktop.nix` to open. `just modules` reconstructs it by static analysis, and
`just modules --reverse` inverts it. If you port the pattern, port that too or
the layout becomes genuinely hard to read.

**If you redo the migration mechanically**, as I did for 104 package files and
~35 nixos modules: the reliable anchor is the `flake.modules.<class>.<name>`
declaration line, and the shapes that broke naive rewriting were files with no
`{ ... }:` header at all (a bare attrset module), files where `{` sits on the
same line as the declaration, files declaring two modules, and files whose
formals had to gain `config`. Wrapping whole-file (prepend a header, append
`;}`) is far safer than trying to splice a sibling attribute in. Verify with
drvPath identity afterwards; the package conversion came out byte-identical,
which is the only reason I trusted it.

---

## 7. Decisions Elly made — do not relitigate these

Each of these was an explicit choice between options I put up, not a default I
picked. Re-deciding them silently would be worse than either answer.

- **Role names: `base` / `desktop` / `handheld`**, chosen over
  `workstation`/`handheld` and over keeping per-host lists with only a shared
  `common`.
- **Home Manager: NixOS-integrated**, chosen over standalone and over keeping
  both deliberately.
- **Package parity across hosts.** When offered a role split so the handheld
  would stop getting `vscode`, `gimp`, `libre-office`, `zoom`,
  `github-desktop`, the answer was keep parity; structure it so the split is
  available later without deciding now. Tenacity therefore still installs the
  full desktop GUI set, on purpose.
- **Full per-file dendritic conversion of `pkgs-hm/`**, chosen over
  role-assignable groups and over a structural tidy. Accepted the boilerplate.
- **starship as the prompt for every shell**, powerlevel10k and its 1,659-line
  config deleted.
- **All four helper scripts** built, rather than a subset.
- **The grep-trail convention was Elly's**: when making an attribute name
  dynamic, leave the old literal string in a comment so the old form stays
  greppable. That is why `primary-user.nix` contains `users.users.elly`.

On tone: this is a homelab config, not production. I over-dramatised a
four-day window where the flake did not evaluate and was told, fairly, that the
repo has gone six months between commits. Calibrate severity accordingly —
"this is broken and here is the fix" rather than incident-report framing.

---

## 8. Techniques that settled questions here

Not novel, but they are what turned guesses into answers, and they all work
from darwin against a Linux-targeted config:

- **`nix build nixpkgs#<pkg>` on darwin, then grep the result.** Most of these
  packages build or substitute fine on aarch64-darwin even though the hosts are
  x86_64-linux. This is how the `ble-import` extension requirement, ble.sh's
  `bleopt` defaults, home-manager's `useUserPackages` behaviour, and whether
  `zsh-autosuggestions` autoloads `add-zsh-hook` were all settled from source
  rather than from documentation or memory. Cheap, and repeatedly caught things
  the docs did not say.
- **Read the *generated* dotfile, not the module.** `just dotfile .zshrc`, or
  `nix eval --raw '...home.file.".zshrc".text'`. Duplication, ordering and
  "later definition wins" bugs are invisible in the `.nix` and obvious with
  `grep -n` on the output. Every shell bug this session was found this way.
- **`git worktree` + a fingerprint expression** for before/after, rather than
  eyeballing a diff. `scripts/diff-config.sh` wraps it. The one trap: a pure
  reordering of module imports permutes `environment.systemPackages` and so
  changes the toplevel hash without changing the package *set* — compare sets
  before concluding a refactor broke something.

---

## 9. What is broken or unfinished, honestly

**Nothing here was ever built or switched.** Every verification in this session
was `nix eval` or `nix flake check`. The dev machine is aarch64-darwin and both
hosts are x86_64-linux, so building them is not possible here without a remote
builder or binfmt, neither of which is set up. Treat every "verified" claim as
"evaluates and produces the expected derivation", never "runs".

- **Does tenacity build? Unknown.** Its toplevel *evaluates* to a drvPath. It
  has never been built or switched. Before this session it could not even
  evaluate, because of `adjustor` and `decky-loader` — **both of which are
  still live on `flake-parts-consolidation`**, at
  `linux-flake/modules/nire/desktop-env/jovian/jovian.nix`. Two further defects
  are live there too: deprecated `initExtraFirst` in
  `modules/nire/shell-config/zsh/zsh.nix`, and a hand-written
  `eval "$(starship init bash)"` duplicating
  `programs.starship.enableBashIntegration` in
  `modules/nire/shell-config/bash/bash.nix`. Full detail in
  `SESSION-CHANGES.md` part 1; that branch also has **no tenacity hardware
  config at all**.
- **The host checks have never run.** They are filtered to x86_64-linux; on
  darwin `nix flake check` exercises only the orphan check and the formatter.
- **The Home Manager cutover has never been performed.** See
  `linux-flake/home-manager-cutover.md`. The risky step is the first switch,
  and collisions are far likelier on tenacity, which has never had HM, than on
  durandal, whose dotfiles are already HM-owned symlinks.
- **`macos/` does not evaluate.** `nire-lysithea-home.nix` imports seven files
  from `linux-flake/configs/home-manager/user-elly/`, deleted in `8244eb9`. I
  fixed three unrelated defects in it (`d08bc50`) but not this — it needs a
  design decision, not a repair.
- **Shell appearance is entirely unverified.** starship as the prompt, ble.sh
  `complete_auto_menu=1`, and the fzf-driven completion menu are all
  correct-by-construction only. `complete_auto_menu` in particular may be
  annoying in practice; it is a one-line revert in `.blerc`.
- **The `allowUnfreePredicate` workaround is gone** — see §2.
- **Two evaluation warnings remain**, both from `home.stateVersion = "22.11"`
  leaving `programs.git.signing.format` and `programs.swaylock.enable` on
  legacy defaults. Not deprecations; resolving them means choosing to adopt new
  behaviour.
- **treefmt is configured but has never been run.**
- **Impermanence was re-enabled on durandal** by Elly in `6875215`, untested by
  me. Given what that module does, worth a deliberate look before switching.
- **`rustdevshell` alias points at `~/nixos/dev-shells/rust#`**, which is stale
  twice over — the dev-shell is at `misc/dev-shells/rust` and the checkout is
  `nixos-configs`. Moved verbatim rather than guessed at.
- **Dead files still in the tree:** `modules/pkgs/cli/dev/python-dev/`'s
  `ruff.toml`, `.flake8` and `sitecustomize.py` are referenced by nothing.
- **`misc/` is entirely orphaned** — not wired into any flake; its only
  referent was the broken `overlays` line removed in `d08bc50`.
- **17 packages are installed both system-wide and in home.** Some deliberate
  ("emergency packages if home-manager dies"), some not; never untangled.
- **`modules.py tree` can miss preamble-bound edges** by design — see §2. It is
  a display tool; `orphans` is the one that must be right.
