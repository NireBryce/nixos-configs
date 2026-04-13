{ den,  ... }:
{
    den.hosts.x86_64-linux.nire-durandal.users = {
        elly = {
            classes = [ "homeManager" ];
        };
    };

    den.ctx.host.includes = [
        den._.hostname # automatically set hostnames
    ];
}
