{ pkgs, ...}:
{
    environment.systemPackages = with pkgs; [
        balena-etcher
    ];
}
