{

    description = "discord gamer chat app that broke containment";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            discord
        ];
    };
}
