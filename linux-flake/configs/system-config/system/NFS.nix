{
    ...
}:
{
    flake.modules.nixos.core.disks = { ... }: {
        fileSystems."/mnt/qnap-erin" = {
            device = "192.168.0.200:/erin-pub";
            fsType = "nfs";
            options = [ "x-systemd.automount" "noauto" ]; # mount share the first time it's accessed (instead of always) 
        };

        # optional, but ensures rpc-statsd is running for on demand mounting
        boot.supportedFilesystems = [ "nfs" ];
    };
}
 