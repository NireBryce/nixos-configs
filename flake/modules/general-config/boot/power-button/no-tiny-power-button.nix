# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# TEMPORARY -- wiki/upkeep-and-admin/temporary-patches-and-hacks.md lists it with its removal
# condition.
{ lib, ... }:
let
# The kernel this workaround was confirmed against. Any other version --
# point release or major -- prints a warning at eval time asking for a
# re-check, because the bump may have fixed the bug or changed it.
confirmedOn = "6.18.57";
in {
    nixos = { config, ... }: {
        # summary: stops the VM-only tiny_power_button driver powering off on a press

        # tiny_power_button is the kernel's driver for VMs: a power-button
        # press calls kill_cad_pid(SIGRTMIN+4), which makes systemd power
        # off at once, before logind or the desktop sees the key. Its Kconfig
        # says `depends on !ACPI_BUTTON`, i.e. it replaces `button`; nixpkgs
        # builds both as modules and both alias acpi*:PNP0C0C:* and
        # acpi*:LNXPWRBN:*, so udev loads both.
        #
        # On 6.18.55 the same press suspended, so tiny presumably found the
        # device already taken by `button` (inferred: that boot's bindings
        # weren't recorded). 6.18.57 carries part of 6.19's
        # rework that makes `button` a platform driver, without "ACPI: scan:
        # Do not bind ACPI drivers to fixed event buttons" -- so tiny, still
        # an ACPI driver, binds PNP0C0C:00 and every press powers off,
        # ignoring HandlePowerKey and PowerDevil's "sleep". Same partial
        # backport, other symptom: https://bbs.archlinux.org/viewtopic.php?pid=2312287
        # Seen on tenacity 2026-10-20 (`ls /sys/bus/acpi/drivers/tiny-power-button/`
        # showed PNP0C0C:00; a signal_generate trace showed the
        # kill_cad_pid stack). Applies to every host in the `boot` category;
        # the forge-runner VM guest isn't in it.
        #
        # Undo when, on a kernel other than `confirmedOn`, with this
        # blacklist removed: /sys/bus/acpi/drivers/tiny-power-button/ binds
        # nothing, and a power-button press suspends.
        boot.blacklistedKernelModules = [ "tiny_power_button" ];

        warnings = lib.optional (config.boot.kernelPackages.kernel.version != confirmedOn) ''
            no-tiny-power-button.nix: the kernel is now ${config.boot.kernelPackages.kernel.version}, not ${confirmedOn}.
            Re-check whether the tiny_power_button blacklist is still needed
            (removal steps in the module and wiki/upkeep-and-admin/temporary-patches-and-hacks.md).
        '';
    };
}
