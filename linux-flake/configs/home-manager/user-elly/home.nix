{ }
# HM config for elly is assembled from all den.aspects.*.homeManager modules
# declared throughout configs/home-manager/user-elly/.
# flake-aspects transposes them: den.aspects.X.homeManager → flake.modules.homeManager.X
# mkNixos (hosts/lib.nix) then passes builtins.attrValues config.flake.modules.homeManager
# to home-manager.users.elly.imports.
