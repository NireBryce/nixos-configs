# working from https://github.com/Misterio77/nix-starter-configs/blob/main/standard/overlays/default.nix
{ 
  ...
}:

{
  nixpkgs.overlays = [ # https://github.com/nix-community/home-manager/issues/5991
    (self: super: {
      utillinux = super.util-linux;
    })
  ];
}
