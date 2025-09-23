{
    pkgs,
    ...
}:

{
    environment.systemPackages = with pkgs; [
        lutris                      # lutris game launcher                      https://lutris.net/
    ];
}
