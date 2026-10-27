# Wiring a host

This chapter adds a machine to the flake from start to finish: the entry
point, the host's own module directory, the `hosts.nix` line, hardware and
disks, the impermanence decision, secrets enrolment, and the tailnet name.
It also says what "done" can honestly mean for a host that has not booted
yet.

## Read this first: the `/root` wipe

> **`WARN-impermanence.nix` deletes `/` on every boot** on any host that
> includes the `impermanence` category. On every boot, in the initrd, it
> deletes the btrfs subvolume that `/` lives on and replaces it with a copy
> of an empty `root-blank` subvolume. If your disk matches the layout the
> module describes, it will delete yours.

What that means in practice:

- **Never install this config wholesale** on a machine you care about.
- `nire-durandal` and `nire-tenacity` include the category. `nire-cube`
  deliberately does not. Look at the specific host's entry point. Don't
  assume "every host" or "no host".
- **The rollback needs `root-blank` to exist**, and no host's config
  creates it. Without it, the unit deletes `/root` and then cannot replace
  it.
- Read the whole of
  `flake/modules/general-config/impermanence/root-rollback/restore-root/WARN-impermanence.nix`
  and the `impermanence-initrd` skill before you change anything near it.
  For anything that touches `fileSystems`, `boot` or the initrd, prefer
  `just boot` to `just switch`, so the running generation stays in the menu
  as a fallback.

Source: header of `WARN-impermanence.nix`; `AGENTS.md`, Safety;
`.agents/rules/impermanence.md`.

## What a host is made of

There are three pieces, plus optional enrolments:

```text
flake/modules/host-config/
├── hosts.nix                      the roster: one mkHost / mkDarwinHost line per machine
├── <name>-configuration.nix       the entry point: includes.<class> = [ … ];  (outside every category)
└── <name>/                        a category named after the host: only its entry point includes it
    ├── configuration/
    ├── hardware/
    └── fixes/
```

Before you start, read the closest worked example. `durandal` is a
workstation with impermanence. `tenacity` is a handheld with impermanence.
`cube` is a workstation-shaped mini PC with a persistent root. `lysithea`
is the darwin example. `forge-runner` is a VM guest on cube, not a
fleet host, which is why it has no `nire-` prefix.

Source: `.agents/skills/new-host-config/SKILL.md`, "Applies to";
`flake/modules/host-config/hosts.nix`.

## Step 1: decide the shape

- **Workstation or handheld?** A workstation includes `"kde-desktop"` and a
  handheld includes `"jovian"`. Both live in `desktop-env`. Include the
  module, never the whole category.
- **Impermanence?** The usual answer is yes, as on durandal and tenacity. If
  the host opts out, say so in its header the way `cube-configuration.nix`
  does, including how `invariants.nix` and `WARN-password-required.nix`
  interact with that choice.
- **CPU and GPU.** AMD hosts include the shared `hardware` category. An
  Intel host skips it and imports the exact `nixos-hardware` module from
  its own hardware file. Never add an `intel` folder under
  `hardware-config/hardware/`, because the AMD hosts would get it too.
- **NixOS or darwin?** Use `mkHost` into `flake.nixosConfigurations`, or
  `mkDarwinHost` into `flake.darwinConfigurations`. There is no
  impermanence on darwin. See [Darwin edge cases](darwin.md).

Source: `.agents/skills/new-host-config/SKILL.md`, "Shape decisions".

## Step 2: the entry point

Copy `durandal-configuration.nix` and adapt it. Shortened:

```nix
{
    includes.nixos = [
        "<name>"        # host-config/<name>/
        "boot"
        "impermanence"  # WARN-impermanence: wipes /root on boot. Delete this line to opt out.
        "hardware"
        "nix"
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

Use the comments to record what you left out and why. Each existing entry
point does this, for example `tenacity-configuration.nix` on `peripherals`
and `containers`, and `cube-configuration.nix` on `b550-suspend-fix.nix`.

Source: `flake/modules/host-config/durandal-configuration.nix`;
`.agents/skills/new-host-config/SKILL.md`, "Wiring" step 1.

## Step 3: the host directory, with suffixed names

Create `host-config/<name>/` with the subfolders you need. Having a
subfolder that holds modules is what makes `<name>` a category. **Suffix
every file with the host name**: `hardware-<name>.nix`,
`boot-<name>.nix`, `nixpkgs-hostPlatform-<name>.nix`,
`nixpkgs-stateVersion-<name>.nix`. Module names share one namespace across
the tree, so a bare `boot.nix` would collide with the `boot` category and
with every other host's copy. dirs-as-categories refuses that and names
both files.

**`system.stateVersion`: copy the reasoning, not the value.** It pins
defaults to the release under which the host's data was first created, and
it is never bumped. A host with no data yet starts on the *current*
release:

```sh
nix eval --raw .#nixosConfigurations.nire-tenacity.config.system.nixos.release
```

Don't copy another host's value. Write a comment explaining the fresh-host
case, not just the string.

**Don't copy hardware-keyed fixes without checking.**
`durandal/fixes/b550-suspend-fix.nix` targets specific PCI IDs on
durandal's board. `cube-configuration.nix` records why it was *not*
carried over.

Source: `.agents/skills/new-host-config/SKILL.md`, "Naming",
"`system.stateVersion`", "Don't copy hardware-keyed fixes blind";
[where-modules-go.md](../../wiki/config-structure/where-modules-go.md),
"Naming".

## Step 4: hardware and disks

**Real hardware you've already scanned.** Put the `fileSystems` and
`boot.initrd.*` output of `nixos-generate-config` into
`<name>/hardware/hardware-<name>.nix`, wrapped as `{ nixos = …; }`. Raw
output fails to evaluate with a misleading `infinite recursion` error. Add
the two things `invariants.nix` checks that generated output may lack:

- `options = [ "fmask=0077" "dmask=0077" ]` on a vfat `/boot`
- `neededForBoot = true` on `/persist`, on an impermanence host

**No hardware yet.** Use the disko generator
`general-config/impermanence/_disko/impermanence-luks-btrfs.nix` rather
than inventing a hardware configuration. That generator has been
evaluated, never run on hardware, and no host imports it today. Call it
like this:

```nix
imports = [
    (import ../../general-config/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
    })
];
```

- **The placeholder device must be obviously fake.** Never use a plausible
  path like `/dev/nvme0n1`. That path exists on tenacity, and disko pointed
  at the wrong machine destroys real data. A fake path fails loudly.
- `includeSecureboot` and `swapSize` are judgement calls for each host. Set
  them explicitly, with a one-line reason.
- **The disk layout and the `impermanence` category are separate steps.**
  You need both.
- **A host can be fully wired and still unable to boot.** `root-blank`
  exists only after disko has run on the real disk. Say so in the host's
  header.

The ordered runbook is [disk-formatting.md](../../wiki/fleet/disk-formatting.md),
and the layout itself is described in
`flake/doc/disko-impermanence-layout.md`.

Source: `.agents/skills/new-host-config/SKILL.md`, "Real hardware, or not
installed yet?";
[disk-formatting-for-agents.md](../../wiki/fleet/disk-formatting-for-agents.md);
`flake/flake.nix` (comment on the `disko` input).

## Step 5: the `hosts.nix` line

```nix
flake.nixosConfigurations = {
    # …
    nire-<name> = mkHost "x86_64-linux" config.flake.modules.nixos.<name>-configuration;
};
```

The attribute name is the base hostname, `nire-<name>`. The system string
must be one listed in `flake.nix`'s `systems`, because `withSystem` fails on
any other.

Source: `flake/modules/host-config/hosts.nix`;
[flake-parts-port-notes.md](../../wiki/config-structure/flake-parts-port-notes.md),
"`withSystem`".

## Step 6: tailnet naming comes for free

Every machine has two names:

- `nire-<x>` is its `networking.hostName`, and `nire-<x>.local` on the LAN.
- `ts-<x>` is its Tailscale device name.

`general-config/system/networking/tailnet-hosts.nix` reads every `nire-*`
name in `hosts.nix` and generates a `Host ts-<x>` ssh entry and a
completion candidate for each, so **a new host needs no edit there**. The
naming rule lives in `flake.lib.fleet` (`tailnetName`). The `ts-` name
itself is set in the Tailscale admin console, outside this repo, so the
code can follow the convention but cannot enforce it. To ssh over the
tailnet, use `ts-<x>`, never `nire-<x>`. `just reach <x>` tries every name.

Source: header of `tailnet-hosts.nix`; `flake/modules/_lib/fleet.nix`;
[hosts.md](../../wiki/fleet/hosts.md), "Two names per machine".

## Step 7: secrets, only when needed

Hosts are not enrolled automatically. When the host needs `secrets.yaml`,
convert its SSH host key to an age recipient with `ssh-to-age`
(`flake/scripts/host-age-key.sh`), add it to
`general-config/system/secrets/.sops.yaml`, and run
`sops updatekeys secrets.yaml`. Don't enrol a host in advance. If a host is
reinstalled or regenerates its host key, its existing enrolment stops
matching. Re-run the key script and compare with `.sops.yaml` rather than
assuming the old enrolment still holds.

To see which secrets exist, use `just read-sops-names`. Never decrypt to
find out.

Source: `.agents/skills/new-host-config/SKILL.md`, "Wiring" step 4;
[impermanence-and-secrets.md](../../wiki/config-structure/impermanence-and-secrets.md),
"Secrets"; `.agents/rules/secrets.md`.

## Step 8: verify, and say how far you got

```sh
git add -A flake/modules/host-config/<name> \
           flake/modules/host-config/<name>-configuration.nix \
           flake/modules/host-config/hosts.nix
just modules
cd flake
nix eval --raw .#nixosConfigurations.nire-<name>.config.system.build.toplevel.drvPath
```

- Force the real toplevel. Cheap attributes can resolve while something
  else is broken.
- If `just check` fails, use `git stash` to confirm the failure isn't
  pre-existing before you blame the new host.
- **Evaluating is not booting.** Tenacity's first real boot found four
  defects that a clean eval and a clean build had both missed (§25 in
  [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)). Write
  "evaluates", not "verified".
- On an impermanence host, a successful boot doesn't prove the rollback
  ran. Compare `/`'s subvolume id across a reboot. It must change every
  boot.

Source: `.agents/skills/new-host-config/SKILL.md`, "Verifying";
[disk-formatting-for-agents.md](../../wiki/fleet/disk-formatting-for-agents.md),
"Confirming the rollback runs".

## Step 9: docs that follow the roster

- Run `just wiki-gen`. It adds the host's row to
  [`wiki/fleet/hosts.md`](../../wiki/fleet/hosts.md); write the Role cell,
  which is the only column written by hand. Then update the "Imported by"
  line on every `wiki/config-structure/categories/*.md` page for a category
  the host now includes.
- `AGENTS.md` keeps no host roster. Edit its Safety section only if the
  list of hosts that wipe `/root` changes.
- Whether the host actually runs what the tree evaluates to is not recorded
  anywhere in the repo. That is answered on the host, with `just baseline`
  or `just diff-deployed`.

Source: `.agents/skills/new-host-config/SKILL.md`, "Wiring" steps 5–6;
`AGENTS.md`, State.
