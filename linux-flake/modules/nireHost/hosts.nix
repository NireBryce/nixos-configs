{ ... }:
# TODO: this is wrong and will need to be modified for flake-parts
{
    den.hosts.x86_64-linux.nire-durandal = {
        home-manager.enable = true;
        users = {
            elly = {
                classes = [ "homeManager" ];
            };
        };
    };

    den.ctx.host.includes = [
        den._.hostname # automatically set hostnames
    ];
    
}
