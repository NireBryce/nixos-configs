{ ... }:
{
    # desc = " logitech/razer mouse manager https://github.com/soxoj/piper";
    flake.modules.homeManager.base =
    { pkgs, ... }:
let
        packageList = with pkgs; [
            piper
        ];
    in 
    {
        home.packages = packageList;
    };
}
