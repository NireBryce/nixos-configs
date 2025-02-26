{ 
    pkgs,
    ...
}:

{
    environment.systemPackages = with pkgs; [
        sunshine
        moonlight-qt
    ];
}
