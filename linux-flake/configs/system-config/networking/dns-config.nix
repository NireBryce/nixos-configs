{
    ...
}:
{
    flake.modules.nixos.networking.dns = { pkgs, ... }: {
        # TODO: why this DNS
        networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];
    };
}
