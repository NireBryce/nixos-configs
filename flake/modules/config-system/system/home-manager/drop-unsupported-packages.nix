# Drop packages nixpkgs cannot build on this system, once, instead of guarding
# them one module at a time. ellyHomeManager is shared verbatim by all four
# hosts, so everything in it has to survive aarch64-darwin as well as
# x86_64-linux; eleven packages each carried a hand-written
# `lib.mkIf (!pkgs.stdenv.isDarwin)` before this existed. All eleven were
# correct, and all eleven were facts about a package restated by hand.
# Skill `nirepackages-platform-support` has that story and `just available`.
#
# nixpkgs already knows: meta.platforms/meta.badPlatforms are the flag and
# `lib.meta.availableOn` is the reader. It reads meta WITHOUT forcing the
# derivation, which is what makes filtering possible at all -- forcing
# `pkgs.vlc.outPath` on aarch64-darwin genuinely throws, so a filter that
# touched rejected packages would fail exactly where it is needed.
#
# WHAT THIS DOES NOT CATCH: `meta.broken`. availableOn reads platforms and
# badPlatforms and nothing else (nixpkgs lib/meta.nix:368-369), so a package
# broken on this platform passes the filter and then fails evaluation anyway
# ("Refusing to evaluate package ... because it has problems: - broken").
# `cod` is the live example (`meta.broken = stdenv.hostPlatform.isDarwin`),
# which is why shell-config's zsh.nix and bash.nix still guard their `cod`
# lines by hand and must keep doing so -- doubly outside this filter's reach,
# since those are `${pkgs.cod}` interpolations in a shell rc string rather
# than home.packages entries.
#
# DARWIN ONLY, deliberately: on Linux an unsupported package should stay a
# loud error, because durandal and tenacity are what this config is written
# for and a package that cannot build there is a mistake worth stopping on.
# And it WARNS by name for every package dropped, which is the only reason
# this is a partition rather than a filter -- dropping something silently is
# how an hour goes into debugging a missing command.
#
# VALUE-LEVEL, NOT IMPORTS-LEVEL, and it has to be: conditioning `imports` on
# pkgs is a real infinite recursion under useGlobalPkgs (users/
# elly-home-manager.nix records someone hitting it), and flake-parts cannot
# do it either -- `flake.modules.<class>.<name>` has no `<system>` axis, and
# under useGlobalPkgs these are evaluated inside the host, which picks its own
# pkgs. It attaches by re-declaring home.packages to add an `apply`: HM
# declares it as a plain `types.listOf types.package` with no apply of its
# own, and the module system merges a second declaration that adds one, so
# everything reading config.home.packages (home.path's buildEnv included)
# sees the filtered list.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }: {
            options.home.packages = lib.mkOption {
                apply = packages:
                    # hostPlatform, not the pkgs.stdenv.isDarwin alias used
                    # elsewhere in this tree: availableOn takes a platform, and
                    # taking both from the same place keeps the test and the
                    # filter talking about one system.
                    if !pkgs.stdenv.hostPlatform.isDarwin then packages
                    else
                        let
                            split = lib.partition
                                (lib.meta.availableOn pkgs.stdenv.hostPlatform)
                                packages;
                            names = map (p: p.pname or p.name or "<unnamed>") split.wrong;
                        in
                            lib.warnIf (split.wrong != [ ])
                                ("home.packages: dropped ${toString (lib.length split.wrong)}"
                                 + " package(s) unsupported on ${pkgs.stdenv.hostPlatform.system}: "
                                 + lib.concatStringsSep " " (lib.sort (a: b: a < b) names))
                                split.right;
            };
        };
}
