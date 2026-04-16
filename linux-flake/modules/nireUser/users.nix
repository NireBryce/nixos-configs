{ den, ... }: {

# default user settings
    den.ctx.user.includes = [
        den._.define-user
    ];

    den.aspects.elly = {
        homeManager = { pkgs, ... }: {
            home.packages = [ pkgs.hello ];
        };
    };

    den.homes.x86_64-linux."elly@nire-durandal" = { };
}
