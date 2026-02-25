# Why this file exists
# ────────────────────
# Two separate libraries are in play:
#
#   den         — provides the `den.aspects` option that every config file
#                 in configs/ writes to.
#
#   flake-aspects — reads from `flake.aspects` and transposes it into
#                   `flake.modules.{nixos,homeManager}`.
#
# These two libraries are independent and use different namespaces.
# den does NOT automatically forward its aspects into flake.aspects.
# This one-liner performs that bridge manually.
#
# Without it, flake-aspects would see an empty flake.aspects and produce
# no modules, so nixosSystem would receive no configuration at all.
{ config, ... }:
{
  flake.aspects = config.den.aspects;
}
