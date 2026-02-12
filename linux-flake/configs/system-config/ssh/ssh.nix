{
    ...
}:
{ den.aspects.nixos.provides.ssh = 
{ ... }: 
{
    services.openssh = {
        enable                          = true;
        allowSFTP                       = false;    # Don't set this if you need sftp
        settings = {
        PasswordAuthentication        = false;
        KbdInteractiveAuthentication  = false;
        };
        extraConfig = ''
            AllowTcpForwarding          yes
            X11Forwarding               no
            AllowAgentForwarding        no
            AllowStreamLocalForwarding  no
            AuthenticationMethods       publickey
        '';
    };
    users.users.elly = { 
        openssh.authorizedKeys.keys = [ # TODO: sopsify or something for belt and suspenders because @munin gets antsy when I link this
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea'' 
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost''
            ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea''
        ];
    };

}
;}
