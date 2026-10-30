# Your first change

This page adds one small package as a [Home Manager](glossary.md#home-manager)
module. Run the commands from the repo root.

## 1. Scaffold the file

```sh
just add-module homeManager packages-config/shell-apps/text-tools/example-tool.nix "one-line description"
```

The first argument is the [module class](glossary.md#module-class). The path is
relative to `flake/modules/` and must sit inside an existing
[category](glossary.md#category) (here `text-tools`, inside `shell-apps`). The
file name becomes the module name. The command writes a stub with a
`# summary:` comment and stages it with `git add`. It refuses an unknown class,
a path outside every category and a name already in use.

## 2. Fill in the body

Replace the stub's `homeManager = _: { ... };` with the following, modeled on
`ripgrep.nix` in the same folder:

```nix
{
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            hello
        ];
    };
}
```

If you create a file by hand instead of with `just add-module`, run `git add`
on it. A flake in a git repository ignores untracked files.

## 3. Check the wiring

```sh
just modules
```

`just modules` evaluates the module graph and reports untracked `.nix` files,
[orphans](glossary.md#orphan), class bodies that set another class's options,
and drift between the wiki and the graph. Output without such a finding means
the file is tracked and reachable.

To see membership, draw the category:

```sh
just module-graph tree --category text-tools
```

Your module should appear under `text-tools`. Every host receives it, because
`elly-home-manager` includes `shell-apps` and a category includes every module
beneath it.

## 4. Evaluate

```sh
cd flake
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.activationPackage.drvPath'
```

The command evaluates the host's whole Home Manager configuration to its
[`drvPath`](glossary.md#drvpath). A `/nix/store/….drv` path means it evaluated.
This shows that the module evaluates, not that it builds or runs; `just build` on
the host is the next step up.

## Details

- [Adding a module](adding-a-module.md): placement, naming and house style.
- [Adding a package](adding-a-package.md): platform guards and the Homebrew
  overlap on darwin.
