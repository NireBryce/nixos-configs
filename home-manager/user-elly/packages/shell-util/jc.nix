{ ... }:
{
    description = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        jc
    ];
    in
    {
        home.packages = packageList;
    };
}
