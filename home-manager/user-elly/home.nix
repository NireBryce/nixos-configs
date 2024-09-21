{ 
  self,
  ...
}:

let flakePath = self;
in let
  elly-aliases = "${flakePath}/home-manager/elly/aliases.nix";
  elly-default-vars = "${flakePath}/home-manager/elly/default-vars.nix";
in {
  imports = [
  # home manager config fragments
    elly-aliases
    elly-default-vars
  ];
}

# TODO: remove the declarations from individual modules such that you can not have to maintain those when you add/remove packages 
# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap

