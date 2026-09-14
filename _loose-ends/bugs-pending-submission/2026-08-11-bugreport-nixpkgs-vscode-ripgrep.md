# nixpkgs: vscode ≥ 1.129 patches the wrong ripgrep on Linux

Written 2026-08-11 against nixpkgs `f13ff45afd1bb73e640eaa08a7066dbed07e3238`,
on x86_64-linux, vscode 1.130.0. Still present on `master` as of the same date,
so a channel bump does not fix it.

Paste-ready for <https://github.com/NixOS/nixpkgs/issues>. Everything below the
"Describe the bug" heading is the report; the last section is local notes and
should be dropped before filing.

**Not filed. Not to be filed on the strength of this file existing** — per
`CLAUDE.md`, filing outside `NireBryce/nixos-configs` needs Elly saying so
explicitly, in those words, for this specific report.

---

## Describe the bug

VS Code 1.129 moved its bundled native binaries into
`resources/app/node_modules.asar.unpacked`. `generic.nix` knows this and
handles it **for Darwin only**, so on Linux the ripgrep replacement is applied
to a copy that Electron never executes.

The result is that VS Code ships with a working ripgrep it does not use and a
vendored one it does, and the vendored one does not run on NixOS. Search fails
at runtime with no build-time error.

Both copies exist in the output:

```
$out/lib/vscode/resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg
    -> /nix/store/…-ripgrep-15.2.0/bin/rg          # replaced by nixpkgs, works

$out/lib/vscode/resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg
    real file, upstream's vendored binary          # what Electron runs, crashes
```

## Steps to reproduce

```console
$ nix build nixpkgs#vscode --no-link --print-out-paths
/nix/store/…-vscode-1.130.0

$ APP=/nix/store/…-vscode-1.130.0/lib/vscode/resources/app

# the copy nixpkgs replaced — fine
$ "$APP/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg" --version
ripgrep 15.2.0

# the copy Electron actually executes
$ "$APP/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg" --version
Segmentation fault (core dumped)
$ echo $?
139
```

In the editor this shows up as a search failure notification. The two commands
above are the objective part and need no GUI.

## Expected behaviour

On Linux with vscode ≥ 1.129, the `node_modules.asar.unpacked` copy is the one
replaced with `pkgs.ripgrep`, as already happens on Darwin.

## Root cause

`pkgs/applications/editors/vscode/generic.nix`, `nodeModulesPath` at line 432:

```nix
nodeModulesPath =
  if stdenv.hostPlatform.isDarwin then
    # 1.129 moved node_modules back into app.asar, shipping native
    # binaries in the asar.unpacked directory like before 1.94
    if lib.versionAtLeast vscodeVersion "1.129.0" then
      "Contents/Resources/app/node_modules.asar.unpacked"
    else if lib.versionAtLeast vscodeVersion "1.94.0" then
      "Contents/Resources/app/node_modules"
    else
      "Contents/Resources/app/node_modules.asar.unpacked"
  else
    "resources/app/node_modules";        # ← Linux: unconditional
```

The comment describes an upstream change that is not platform specific, but the
version check that acts on it sits inside the `isDarwin` branch. The Linux
branch has had the same value since before 1.94.

`nodeModulesPath` feeds `vscodeRipgrep` (line 467), which is what the
`useVSCodeRipgrep == false` path removes and re-links (line 469).

## Suggested fix

Lift the 1.129 check out of the platform conditional, so both branches pick
`node_modules.asar.unpacked` for ≥ 1.129:

```nix
nodeModulesPath =
  let
    prefix = if stdenv.hostPlatform.isDarwin then "Contents/Resources/app" else "resources/app";
  in
  if lib.versionAtLeast vscodeVersion "1.129.0" then
    "${prefix}/node_modules.asar.unpacked"
  else if lib.versionAtLeast vscodeVersion "1.94.0" then
    "${prefix}/node_modules"
  else
    "${prefix}/node_modules.asar.unpacked";
```

That preserves the existing Darwin behaviour exactly and gives Linux the same
1.94/1.129 treatment. Worth confirming the pre-1.94 case against a Linux build
of that era before merging — the current Linux branch does not distinguish it,
so the history there is not visible from the expression alone.

## Additional context

- `vscodium` is built from the same `buildVscode`/`generic.nix` and is
  currently 1.126.04524, below the threshold, so it is not affected yet. It
  will be at its next bump past 1.129.
- Affects `vscode` and `vscode-fhs` alike, since the FHS wrapper wraps this
  same derivation.
- Nothing fails at build time. `useVSCodeRipgrep = false` removes and re-links
  a path that does exist, so the substitution succeeds against the wrong file.

### Workaround

Until it is fixed, an overlay that re-links the executed copy:

```nix
nixpkgs.overlays = [
  (final: prev: {
    vscode = prev.vscode.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        rg=$out/lib/vscode/resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg
        if [ -e "$rg" ]; then
          rm "$rg"
          ln -s ${final.ripgrep}/bin/rg "$rg"
        fi
      '';
    });
  })
];
```

**Untested as written.** It needs building, and if `vscode-fhs` is what you
install, it also needs checking that the override reaches through the FHS
wrapper rather than leaving the sandbox pointed at the unfixed derivation.

---

## Local notes — remove before filing

Found on `nire-tenacity` while diagnosing two VS Code notifications after the
nixpkgs 26.05 → 26.11 bump moved VS Code from 1.109.5 to 1.130.0.

The other notification, about the keyring, is **not** this bug and not a
nixpkgs one: VS Code guesses its credential backend and guesses wrong on
Plasma 6. That is fixed with `"password-store": "kwallet6"` in
`~/.vscode/argv.json`, and is recorded in the history block of
`flake/modules/nirePackages/editors/vscode/vscode.nix`.

Neither is caused by this repo moving vscode from `programs.vscode` to
`environment.systemPackages`, which was checked: that module sets only
`environment.systemPackages`, plus `sessionVariables.EDITOR` and an
`/etc/vscode/policy.json` that are both gated on options this config never set.
