# Declares the `environment.persistence` option for every NixOS host, whether
# or not that host actually wipes anything. Nothing else. No bind mounts
# happen unless something populates environment.persistence."/persist" with
# actual entries -- this file alone is a complete no-op.
#
# Added alongside nire-testbed, the first NixOS host in this repo that does
# NOT import `impermanence`. tailscale-persist.nix (and jovian-persist.nix)
# write to environment.persistence."/persist" unconditionally, and each
# already carries a comment anticipating this: "A future host taking `system`
# WITHOUT [impermanence] would hit an option-does-not-exist error here and
# would need this guarded, not just deleted." This is that guard -- but it
# guards the OPTION, not the value, because the value can't be:
#
#   lib.mkIf false { environment.persistence."/persist".directories = [...]; }
#
# still throws "The option `environment.persistence' does not exist" if no
# module anywhere declares it -- mkIf only makes the VALUE conditional, and
# the module system validates config *structure* against declared options
# unconditionally, before mkIf's condition is even resolved. Confirmed with
# `lib.evalModules` before writing this file, not assumed. Gating the
# `imports` list instead (`lib.optional (options ? ...) ...`) was the other
# candidate, and it fails harder: referencing `options` (or `config`) of the
# same evalModules call from within that call's own `imports` list is exactly
# the circular-imports shape CLAUDE.md documents for pkgs under useGlobalPkgs,
# except here it is `options` doing it, not `pkgs` -- also confirmed with
# evalModules, and it throws "infinite recursion encountered" identically.
#
# So the option has to just always exist. This is that.
#
# Safe for durandal and tenacity too: they already import `impermanence`,
# which imports this same flake module. Importing the same module twice from
# two different files is idempotent -- the module system deduplicates by
# reference -- so this changes nothing for either of them.
#
# Verified functionally safe, not just evaluation-safe: read
# inputs.impermanence.nixosModule's nixos.nix directly. Its
# system.activationScripts run a createDirectories script that mkdir -p's the
# persistentStoragePath side of every configured directory before bind
# mounting, so a host whose /persist is a plain directory on its ordinary
# persistent root (testbed's situation) does not need /persist to be its own
# filesystem or mountpoint at all -- the bind mount ends up being one
# directory onto a sibling directory on the same filesystem, which is a
# little redundant and entirely functional.
{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            imports = [ inputs.impermanence.nixosModule ];
        };
}
