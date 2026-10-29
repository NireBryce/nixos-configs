# Your first change

This page adds one small package as a Home Manager module. Run the commands
from the repo root.

## 1. Scaffold the file

```sh
just add-module homeManager packages-config/shell-apps/text-tools/example-tool.nix "one-line description"
```

The path is relative to `flake/modules/` and must sit inside an existing
category. The file name becomes the module name. The command writes a stub and
stages it with `git add`. It refuses an unknown class, a path outside every
category and a name already in use.

## 2. Fill in the body

Replace the stub's class lambda, using `ripgrep.nix` in the same folder as the
model:

```nix
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            hello
        ];
    };
}
```

If you edited or created the file by hand, run `git add` on it again. An
untracked file does not exist to the flake.

## 3. Check the wiring

```sh
just modules
```

It reports untracked `.nix` files, orphans (modules no host reaches) and drift
between the docs and the evaluated module graph. No output of that kind means
the file is tracked and reachable.

To see membership, draw the category:

```sh
just module-graph tree --category text-tools
```

Your module should appear under `text-tools`. It reaches every host whose
Home Manager aggregate includes that category.

## 4. Evaluate

```sh
cd flake
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

A `/nix/store/….drv` path means the whole configuration evaluated. It proves
the module evaluates, not that it builds or runs; `just build` is the next
level.

## Details

- [Adding a module](adding-a-module.md): placement, naming and house style.
- [Adding a package](adding-a-package.md): platform guards and the Homebrew
  overlap on darwin.
