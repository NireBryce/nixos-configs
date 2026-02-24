# den.aspects is NOT automatically forwarded to flake.aspects.
# Den's own mechanism is den.hosts-based; this project uses flake-aspects'
# transposition instead. This module manually bridges the two so that every
# den.aspects.X.{nixos,homeManager} declaration ends up in
# config.flake.modules.{nixos,homeManager}.X via flake-aspects.
{ config, ... }:
{
  flake.aspects = config.den.aspects;
}
