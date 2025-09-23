# working from https://github.com/Misterio77/nix-starter-configs/blob/main/standard/overlays/default.nix
{ 
  inputs, 
  ...
}:
  # let
  #   nixpkgsUnstable = import <nixpkgs-unstable> { };
  # in
{
  nixpkgs.overlays = [ # https://github.com/nix-community/home-manager/issues/5991
    (self: super: {
      utillinux = super.util-linux;
    })
  ];

  # # TODO: no idea where i was going with this
  # stable-packages = final: _prev: {
  #   stable = import inputs.nixpkgs-stable {
  #     system = final.system;
  #     config.allowUnfree = true;
  #   };
  # };
}
