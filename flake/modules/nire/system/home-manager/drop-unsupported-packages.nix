# Drop packages nixpkgs cannot build on this system, once, instead of guarding
# them one module at a time.
#
# ellyHomeManager is shared verbatim by all three hosts, so every package in it
# has to survive aarch64-darwin as well as x86_64-linux. Eleven did not -- vlc,
# gimp, libreoffice-qt, github-desktop, piper, qpwgraph, strace, ltrace, iotop,
# sysstat, ethtool -- and each one carried a hand-written
# `lib.mkIf (!pkgs.stdenv.isDarwin)`. That works, and all eleven were correct,
# but it is a fact about the package restated by hand in the config, which is
# the shape that eventually disagrees with reality. `just available --all`
# was written because checking those claims by hand was tedious enough that
# nobody did it; this makes the claims unnecessary instead.
#
# nixpkgs already knows. meta.platforms and meta.badPlatforms are the flag, and
# lib.meta.availableOn is the reader. Critically it reads meta WITHOUT forcing
# the derivation, which is what makes filtering possible at all: forcing
# pkgs.vlc.outPath on aarch64-darwin genuinely throws, so a filter that touched
# rejected packages would fail exactly where it is needed.
#
# ── what this does NOT catch ─────────────────────────────────────────────────
#
# `meta.broken`. availableOn reads platforms and badPlatforms and nothing else
# (nixpkgs lib/meta.nix:368-369), so a package marked broken on this platform
# passes the filter and then fails evaluation anyway, with "Refusing to
# evaluate package ... because it has problems: - broken". `cod` is the live
# example -- `meta.broken = stdenv.hostPlatform.isDarwin` in its package.nix --
# which is why nire/shell-config/{zsh,bash}.nix still guard their `cod` lines
# by hand and must keep doing so. That guard is also outside this filter's
# reach for a second reason: it is a ${pkgs.cod} interpolation inside a shell
# rc string, not an entry in home.packages.
#
# ── how it attaches ──────────────────────────────────────────────────────────
#
# By re-declaring home.packages to add an `apply`. Home Manager declares it as a
# plain `types.listOf types.package` with no apply of its own
# (home-manager/modules/home-environment.nix), and the module system merges a
# second declaration that adds one. Everything reading config.home.packages --
# home.path's buildEnv included -- sees the filtered list.
#
# This is a value-level filter, not an imports-level one, and it has to be.
# Conditioning `imports` on pkgs is a real infinite recursion under
# useGlobalPkgs; nireUser/elly-home-manager.nix records someone hitting it. It
# also cannot be done from flake-parts: flake.modules.<class>.<name> has no
# <system> axis, and under useGlobalPkgs these modules are evaluated inside the
# host, which chooses its own pkgs.
#
# ── why darwin only ──────────────────────────────────────────────────────────
#
# On Linux an unsupported package should stay a loud error. durandal and
# tenacity are the platforms this config is actually written for, so a package
# that cannot build there is a mistake worth stopping on, not something to
# quietly route around. Filtering everywhere would turn that into a silent
# omission -- the same failure mode CLAUDE.md warns about for module names that
# disagree with their filename.
#
# ── and why it still warns ───────────────────────────────────────────────────
#
# Dropping a package without saying so is how you end up debugging a missing
# command for an hour. The warning names every package removed, so `nh darwin
# build` says what happened. It is the only reason this is a partition rather
# than a filter.
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
