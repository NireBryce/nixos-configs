{ }
# This file is intentionally empty.
#
# Elly's home-manager configuration is assembled automatically from every
# den.aspects.<name>.homeManager declaration found under this directory.
# import-tree discovers each .nix file; flake-aspects transposes the aspects
# into flake.modules.homeManager; elly-home.nix passes them all to
# home-manager.lib.homeManagerConfiguration.
#
# There is nothing to add here. To configure a new program, create a new
# .nix file anywhere under configs/home-manager/user-elly/ with:
#
#   { den.aspects.<name>.homeManager = { pkgs, ... }: { /* HM options */ }; }
