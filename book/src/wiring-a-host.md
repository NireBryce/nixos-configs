# Wiring a host

Adding a machine to the flake touches the entry point, the host's own
module directory, the `hosts.nix` line, hardware and disks, the impermanence
decision, secrets enrollment, and the tailnet name. Step 8 says what
"done" can mean for a host that has not booted yet.

## Read this first: the `/root` wipe

> **`WARN-impermanence.nix` deletes the root filesystem on every boot** on
> any host that includes the `impermanence` category. In the initrd, it
> deletes the btrfs subvolume that `/` lives on and replaces it with a copy
> of an empty `root-blank` subvolume. If your disk matches the layout the
> module describes, it will delete yours.

This setup is called [impermanence](glossary.md#impermanence): anything on
`/` that is not explicitly persisted is gone after the next boot.

- Never install this config wholesale on a machine you care about.
- Check the specific host's entry point. A host that leaves the
  `impermanence` category out says so in its header.
- The rollback needs a `root-blank` subvolume, and no host's config creates
  it. Without it, the unit deletes the root subvolume and cannot replace it.
- Before changing anything near it, read
  `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
  and the `impermanence-initrd` skill. For changes to `fileSystems`, `boot`
  or the initrd, use `just boot` instead of `just switch`, so the running
  generation stays in the boot menu.

## What a host is made of

```text
flake/modules/host-config/
├── hosts.nix                      the roster: one mkHost / mkDarwinHost line per machine
├── <name>-configuration.nix       the entry point: includes.<class> = [ … ];  (outside every category)
└── <name>/                        a category named after the host: only its entry point includes it
    ├── configuration/
    ├── hardware/
    └── fixes/
```

The [entry point](glossary.md#entry-point) lists the host's
[categories](glossary.md#category). Before you start, find the closest worked
example in `host-config/hosts.nix` or
[`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md), which list each host and
its role. Each entry point sits beside `hosts.nix`. Pick one with the same
shape as yours: workstation or handheld, impermanence or persistent root,
NixOS or darwin. A VM guest such as `forge-runner` is a component of a host,
not a fleet machine, so it has no `nire-` prefix.

## Step 1: decide the shape

- Workstation or handheld? A workstation includes `"kde-desktop"` and a
  handheld includes `"jovian"`. Both modules live in `desktop-env`. Include
  the module, never the whole category.
- Impermanence? The usual answer is yes. A host that opts out says so in its
  header, as `cube-configuration.nix` does, including how `invariants.nix`
  (evaluation-time checks on every NixOS host) and `WARN-password-required.nix` interact with that choice.
- CPU and GPU? AMD hosts include the shared `hardware` category. An Intel
  host skips it and imports the exact `nixos-hardware` module from its own
  hardware file. Never add an `intel` folder under
  `hardware-config/hardware/`, because the AMD hosts would get it too.
- NixOS or darwin? Use `mkHost` into `flake.nixosConfigurations`, or
  `mkDarwinHost` into `flake.darwinConfigurations`. Darwin has no
  impermanence. See [Darwin edge cases](darwin.md).

## Step 2: write the entry point

Copy `durandal-configuration.nix` and adapt it. Abridged (the real file
has more comments and one more category line than shown):

```nix
{
    includes.nixos = [
        "<name>"        # host-config/<name>/
        "boot"
        "impermanence"  # WARN-impermanence -- wipes /root on boot, see the module.
        "hardware"
        "nix"
        "peripherals"
        "shell-config"
        "system"
        "kde-desktop"
        "development" "editors" "gui-other" "linux-utils"
        "nix-utils" "shell-apps" "terminals"
        "elly"
    ];
    nixos.networking.hostName = "nire-<name>";
}
```

`includes.nixos` lists the modules and categories of the `nixos` class that
the host takes. Use comments to record what you left out and why, as
`tenacity-configuration.nix` does for `peripherals` and `containers`, and
`cube-configuration.nix` for `b550-suspend-fix.nix`. Every name must exist,
or evaluation in step 8 stops with an unknown-name error.

## Step 3: create the host directory, with suffixed names

Create `host-config/<name>/` with the subfolders you need. A subfolder that
holds modules makes `<name>` a category.

**Suffix every file with the host name**: `hardware-<name>.nix`,
`boot-<name>.nix`, `nixpkgs-hostPlatform-<name>.nix`,
`nixpkgs-stateVersion-<name>.nix`. Module names share one namespace, so a
bare `boot.nix` would collide with the `boot` category and with every other
host's copy. dirs-as-categories, the flake input that names modules after
their files, refuses the collision and names both files.

Copy the reasoning, not the value. `system.stateVersion` pins defaults to the release under which the host's
data was first created, and is never bumped. A host with no data yet starts
on the current release:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Do not copy another host's value. Write a comment next to the string that
explains the fresh-host case.

Do not copy hardware-keyed fixes unchecked.
`durandal/fixes/b550-suspend-fix.nix` targets specific PCI IDs on
durandal's board, and `cube-configuration.nix` records why it was not
carried over.

## Step 4: describe hardware and disks

For real hardware you have already scanned, put the `fileSystems` and
`boot.initrd.*` output of `nixos-generate-config` into
`<name>/hardware/hardware-<name>.nix`, wrapped as `{ nixos = …; }` (raw
output asks for `modulesPath` and is refused). Then add the two settings that
`invariants.nix` checks and generated output may lack:

- `options = [ "fmask=0077" "dmask=0077" ]` on a vfat `/boot`
- `neededForBoot = true` on `/persist`, on an impermanence host

With no hardware yet, use the disko generator (disko partitions
and formats disks from a Nix description)
`general-config/impermanence/_disko/impermanence-luks-btrfs.nix` instead of
inventing a hardware configuration. It has been evaluated but never run on
hardware, and no host imports it today. From a file directly in
`host-config/<name>/`:

```nix
imports = [
    (import ../../general-config/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
    })
];
```

Two adjustments to the excerpt:

- The generator produces only `disko.devices` and `fileSystems` values.
  Import `inputs.disko.nixosModules.disko` beside it, or evaluation fails on
  an unknown option.
- Write the path relative to the file it sits in. A file in
  `<name>/hardware/` needs `../../../` where the excerpt shows `../../`.

Rules for the generator:

- The placeholder device must be obviously fake. A plausible path like
  `/dev/nvme0n1` exists on tenacity, and disko pointed at the wrong machine
  destroys real data. A fake path fails loudly.
- Set `includeSecureboot` and `swapSize` explicitly for each host, with a
  one-line reason.
- The disk layout and the `impermanence` category are separate; you need
  both.
- `root-blank` exists only after disko has run on the real disk, so a fully
  wired host can still be unable to boot. Say so in the host's header.

The ordered runbook is [disk-formatting.md](../../wiki/fleet/disk-formatting.md).
The layout is described in `flake/doc/disko-impermanence-layout.md`.

## Step 5: add the `hosts.nix` line

```nix
flake.nixosConfigurations = {
    # …
    nire-<name> = mkHost "x86_64-linux" config.flake.modules.nixos.<name>-configuration;
};
```

The attribute name is the base hostname, `nire-<name>`. The system string
must be one listed in `flake.nix`'s `systems`, because `withSystem` fails on
any other. The eval in step 8 reports an unlisted string.

## Step 6: confirm the tailnet name (no edit needed)

Every machine has two names:

- `nire-<x>` is its `networking.hostName`, and `nire-<x>.local` on the LAN.
- `ts-<x>` is its Tailscale device name.

`general-config/system/networking/tailnet-hosts.nix` reads every `nire-*`
name in `hosts.nix` and generates a `Host ts-<x>` ssh entry and a completion
candidate for each, so **a new host needs no edit there**. The naming rule
is `tailnetName` in `flake.lib.fleet`. The `ts-` name itself is set in the
Tailscale admin console, outside this repo, so the code follows the
convention but cannot enforce it. To ssh over the tailnet, use `ts-<x>`,
never `nire-<x>`. `just reach <x>` tries every name.

## Step 7: enroll secrets, only when needed

Hosts are not enrolled automatically. When the host needs `secrets.yaml`:

1. Convert its SSH host key to an age recipient with `ssh-to-age`
   (`flake/scripts/host-age-key.sh`).
2. Add the recipient to `general-config/system/secrets/.sops.yaml`.
3. Run `sops updatekeys secrets.yaml`.

Do not enroll a host in advance. A reinstall or a regenerated host key
invalidates the enrollment, so re-run the key script and compare its output
with `.sops.yaml`.

To see which secrets exist, use `just read-sops-names`. Never decrypt to
find out.

## Step 8: verify, and say how far you got

```sh
git add -A flake/modules/host-config/<name> \
           flake/modules/host-config/<name>-configuration.nix \
           flake/modules/host-config/hosts.nix
just modules
cd flake
nix eval --raw .#nixosConfigurations.nire-<name>.config.system.build.toplevel.drvPath
```

`just modules` reports untracked files and module-graph drift. The `nix eval`
prints a `/nix/store/….drv` path on success.

- Force the whole toplevel. Evaluating the toplevel's
  [`drvPath`](glossary.md#drvpath) forces the whole configuration without
  building it, while cheap attributes can resolve with something else broken.
- If `just check` fails, use `git stash` to confirm the failure is not
  pre-existing before you blame the new host.
- Evaluating is not booting: a host's first real boot found defects that a
  clean eval and build both missed ([lesson 25](../../wiki/agent-lessons-learned/25-running-is-its-own-rung.md)).
  Write "evaluates", not "verified".
- On an impermanence host, a successful boot does not prove the rollback
  ran. Compare `/`'s subvolume id across a reboot; it must change every boot.

## Step 9: update the docs that follow the roster

- Run `just wiki-gen`. It adds the host's row to
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md); write the Role cell,
  the only column written by hand. Then update the "Imported by" line on
  every `wiki/config-structure/categories/*.md` page for a category the host
  now includes.
- `AGENTS.md` keeps no host roster. Edit its Safety section only if the list
  of hosts that wipe `/root` changes.
- The repo does not record whether the host runs what the tree evaluates to.
  Answer that on the host with `just baseline` or `just diff-deployed`.

## Sources

- `flake/modules/host-config/hosts.nix`, `durandal-configuration.nix`
- `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
- `flake/modules/general-config/system/networking/tailnet-hosts.nix`, `flake/modules/_lib/fleet.nix`
- `flake/scripts/host-age-key.sh`, `flake/doc/disko-impermanence-layout.md`
- `.agents/skills/new-host-config/SKILL.md`, `.agents/rules/impermanence.md`, `.agents/rules/secrets.md`, `AGENTS.md`
- [hosts.md](../../wiki/fleet/hosts.md)
- [disk-formatting-for-agents.md](../../wiki/fleet/disk-formatting-for-agents.md)
- [where-modules-go.md](../../wiki/config-structure/where-modules-go.md)
- [flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md)
- [impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md)
