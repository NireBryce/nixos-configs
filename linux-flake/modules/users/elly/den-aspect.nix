{ 
    inputs,
    elly,
    packages,
    ...
}:
{
    inputs.den.aspects.elly.includes = [
        elly.aliases
        elly.fonts
        elly.git
        elly.hm-settings
        elly.home-config
        elly.user
        packages.linux
    ];

}
