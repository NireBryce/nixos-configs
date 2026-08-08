# Session changes on `flake-parts`, and how to get them onto `flake-parts-consolidation`

Written 2026-08-07, on the `flake-parts` branch. Read either document from
`flake-parts-consolidation` without checking anything out:

```sh
git show flake-parts:SESSION-CHANGES.md
git show flake-parts:SESSION-HANDOFF.md
```

Delete both once the work is ported.

## The situation

37 commits were made on `flake-parts`, from `2e09402` (exclusive) to `6677636`.
All are pushed to `origin/flake-parts`, so **nothing is at risk** — this is a
question of porting, not recovery.

The catch:

| | |
|---|---|
| common ancestor | `cec2b84` ("oops") |
| `flake-parts-consolidation` has | 133 commits we lack |
| we have | 39 commits it lacks (37 of them this session) |
| layout on ours | `modules/{nire,hosts,pkgs,users}` + `roles.nix`, `checks.nix` |
| layout on theirs | `modules/{nire,nireHost,nirePackages,nireUser}` + `entrypoint.nix` |

Of the files this session changed most, only `linux-flake/flake.nix` exists on
both branches. `zsh.nix`, `hosts.nix`, `roles.nix`, `checks.nix` and the whole
`modules/pkgs/` tree are at different paths or absent.

**So cherry-picking is not viable for most of this.** `git cherry-pick` needs
paths to line up and they do not. Port by intent, using this document, and
cherry-pick only the few file-additions listed in part 3.

---

## Part 1 — bugs that still exist on `flake-parts-consolidation`

Port these first; they are real defects on that branch, independent of layout.

**`linux-flake/modules/nire/desktop-env/jovian/jovian.nix`**

1. **`adjustor` was removed from nixpkgs**, folded into `handheld-daemon`.
   Referencing it fails evaluation outright:
   `error: adjustor has been removed as it part of the 'handheld-daemon' package`.
   Fix: delete it from `environment.systemPackages`. The
   `services.handheld-daemon.adjustor` option already pulls it in.
   *(our commit `5d69848`)*

2. **`inputs.jovian.decky-loader.extraPackages` does not exist.** The Jovian
   flake exposes only `nixosModules`, `legacyPackages`, `overlays`, `checks`,
   `devShells`, `githubActions`. The intended reference is the module option
   the same file sets: `config.jovian.decky-loader.extraPackages`.
   *(same commit)*

Both of these mean **tenacity cannot build**. They are invisible until
something forces the host's toplevel — evaluating `networking.hostName`
succeeds fine.

**`linux-flake/modules/nire/shell-config/zsh/zsh.nix`**

3. **`programs.zsh.initExtraFirst` / `initExtraBeforeCompInit` / `initExtra`
   are deprecated** in favour of one `initContent`. Mapping that preserves
   ordering: `initExtraFirst` → `lib.mkBefore`, `initExtraBeforeCompInit` →
   `lib.mkOrder 550`, `initExtra` → unordered, all inside `lib.mkMerge`.
   Move only the option and delimiter lines; leave the `''` bodies untouched so
   indentation stripping does not change. *(our commit `e0278d2`)*

**`linux-flake/modules/nire/shell-config/bash/bash.nix`**

4. **`eval "$(starship init bash)"` runs alongside
   `programs.starship.enableBashIntegration`**, so starship initialises twice.
   Drop the hand-written line; the HM integration also uses the store path
   rather than relying on `PATH`. *(our commit `118c53d`)*

Checked and **not** present on that branch: `xorg.xwininfo`, the invalid
`flake.modules.jovian` class, and any unwrapped `hardware-configuration.nix`
(its durandal one is correctly wrapped). Note it has **no tenacity hardware
config at all**.

---

## Part 2 — the 37 commits

`P` = portable as an idea, needs rewriting for the other layout.
`F` = file addition, mostly path-agnostic (see part 3).
`N` = does not apply / already different there.

### Broken-flake fixes
- `922289e` **fixed tenacity hardware-configuration not being a flake-parts module** — `N` (theirs is wrapped). Raw `nixos-generate-config` output under `modules/` makes flake-parts resolve `modulesPath` via its own `_module.args` → infinite recursion, killing every output.
- `5added8` **jovian module moved off an invalid `"jovian"` class** — `N`. flake-parts stamps the outer attr name as `_class` unvalidated; only `nixos`/`homeManager`/`flake`/`generic` mean anything.
- `5d69848` **two evaluation errors in the jovian module** — `P`, **see part 1**.

### Structure
- `319d67b` **per-host import lists → `base`/`desktop`/`handheld` roles** — `P`. Each module opts *itself* in next to its definition; `flake.modules.<class>.<name>` is a `deferredModule` so many files merge into one aggregate. Consolidation's dirs-as-categories does something similar; compare before redoing.
- `97b38bf` **same opt-in treatment for homeManager**, killing `removeAttrs self.modules.homeManager [...]` — `P`.
- `72a2bf7` **each package its own flake-parts module** (`pkgs-hm/` → `modules/pkgs/`, 104 files) — `P`, but consolidation already has `nirePackages`; likely redundant.
- `e180eb0` **`nixosConfigurations` via `withSystem`** — `P`. Gives hosts `self'`/`inputs'` through `specialArgs`. Deliberately does *not* take `pkgs` from perSystem: that instance has no `nixpkgs.config`, so `allowUnfree` would be lost.
- `ac1e2f1` **`nire.primaryUser`**, replacing hardcoded `"elly"` in six places — `P`. Note the comment carries the literal `users.users.elly` so grepping the old form still lands somewhere.
- `cd520dc` **Home Manager managed from NixOS** (`useGlobalPkgs`, `useUserPackages`), dropping `homeConfigurations` — `P`. Consolidation has commits about "disabling standalone homes"; check what it settled on.

### Checks and tooling — `F`
- `d93fb52` `perSystem.checks` forcing each host's toplevel, filtered by system.
- `d5b72d8` `nix fmt` via treefmt-nix, `flakeCheck = false` until the tree is formatted.
- `8463987` + `6677636` `scripts/modules.py`: `orphans` (a flake check for modules nothing imports) and `tree` (what each aggregate contains).
- `35afdf4` `scripts/{diff-config.sh,dotfile.sh,add-pkg.sh,new-host-hardware.sh}` + `host-fingerprint.nix`, wired as just recipes.
- `7dd07cf` `.justfile` given real recipes; `update-flake.sh` no longer truncated mid-line.
- `4aaeefc` deleted the dead den migration scripts.

### Shell
- `526ddc7` answered the three "magic, no idea what it does" zsh TODOs: `typeset -U` dedupes the arrays; `add-zsh-hook` was unused; `zmodload zsh/terminfo` is needed by `initial-bindings.zsh` for Home/End, **not** kitty. Also found four aliases that were dead because `home.shellAliases` is emitted *after* `initContent` and wins.
- `3443c94` deleted the zi remnants — `zi.zsh`/`zi-plugins.zsh` were never sourced, so "MIGRATE OFF ZI" was already done.
- `aa38936` then `b939b62` **powerlevel10k → starship for all shells**. p10k's config was being injected while the theme was never loaded, and starship's init ran after it and won regardless. Net effect: `.zshrc` 106,449 → 18,780 bytes.
- `118c53d` **ble.sh completions made zsh-like** — `P`, plus **see part 1**. `complete_auto_menu=1`, and the `fzf-menu`/`bash-completion`/`nix-completion` contrib imports. Also fixed `.blerc` being generated twice because two modules declared it and `home.file.<n>.text` is `types.lines`, which concatenates.
- `e0278d2` zsh deprecations + `xorg.xwininfo` — **see part 1**.

### macOS / hygiene
- `d08bc50` **`macos/flake.nix`**: removed a broken `overlays` output (`../misc/overlays` does not exist *and* `../` escapes the flake root), a stale `sops-nix.inputs.nixpkgs-stable.follows`, and the unused `home-manager-unstable` input. Worth porting — likely present on consolidation too.
- `e62d0cf` `flake.nix`: filled `description`, dropped the `pipe-operators` `nixConfig` (unused, costs a trust prompt), dropped the unused `darwin` input.
- `ee4a0e0`, `ca64483` deleted `error.txt`, `further-reading,md`, duplicate `.vscode/` dirs; untracked `.DS_Store`.

### Docs — `F`
- `d471378`, `96e621f`, `2d86d42`, `3bf8c1a`, `f1390d4` `CLAUDE.md`.
- `f551afa` `linux-flake/flake-parts-reference.md`.
- `aa55a9f`, `ac4b00b` `linux-flake/2026-08-06 changelog.md`.
- `7cb8ba4` `linux-flake/home-manager-cutover.md`.

### Yours, during the session
- `bd3e752` removed the unused `pkgs` arg from tenacity's hwconfig.
- `6875215` re-enabled impermanence on durandal.

---

## Part 3 — what can be moved as whole files

These are new files with few or no dependencies on the module layout. Fastest
route is to copy them across rather than cherry-pick:

```sh
git checkout flake-parts -- CLAUDE.md
git checkout flake-parts -- linux-flake/flake-parts-reference.md
git checkout flake-parts -- linux-flake/home-manager-cutover.md
git checkout flake-parts -- "linux-flake/2026-08-06 changelog.md"
git checkout flake-parts -- linux-flake/scripts/
git checkout flake-parts -- .justfile
```

Then adjust:

- `scripts/modules.py` — works on any tree using `flake.modules.<class>.<name>`;
  the `orphans` entry-point heuristic assumes the file naming host configs
  declares no modules of its own. Check that holds for `entrypoint.nix`.
- `scripts/host-fingerprint.nix` — reads `cfg.nire.primaryUser`; either port
  `nire.primaryUser` too or change that line.
- `scripts/dotfile.sh` — same `nire.primaryUser` dependency.
- `scripts/add-pkg.sh` — hardcodes `modules/pkgs/{cli,gui,linux-utils}` and the
  `pkgs-*` aggregate names; retarget at `nirePackages`.
- `.justfile` — recipe paths assume `linux-flake/scripts/`.
- `CLAUDE.md` — describes *this* branch's layout throughout. Useful as a
  starting point, but the aggregate table and the Shells section need rewriting.
- `modules/checks.nix` — the host-toplevel check is layout-independent; the
  orphan check just needs the right path to `modules.py`.

---

## Part 4 — doing the port

Nothing is lost: all 37 commits are on `origin/flake-parts`.

Suggested order, from most to least mechanical:

1. **Part 1 bug fixes** — small, self-contained, and two of them mean tenacity
   cannot build. Do these even if nothing else gets ported.
2. **Part 3 file copies** — scripts, checks and docs, with the adjustments noted.
3. **Structural work** — re-apply by intent, comparing against what
   consolidation already did. Do not force ours over theirs; they solved some of
   the same problems differently.

To see any individual change in full:

```sh
git show <sha>                 # e.g. git show 5d69848
git log -p 2e09402..6677636 -- <path>
```

To compare a file across the branches:

```sh
git diff flake-parts origin/flake-parts-consolidation -- linux-flake/flake.nix
```

One thing worth carrying over regardless of layout: **everything in this session
was verified by evaluation only.** Nothing was built or switched — the dev
machine is darwin and both hosts are `x86_64-linux`. The host checks have never
actually run.
