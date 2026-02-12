{ den.aspects.nixos.provides.virtualization = 
{ ... }:
{
        # User-scoped `~/.config/containers/registries`
        # https://wiki.nixos.org/wiki/Podman#DevContainers
        xdg.configFile."containers/registries.conf".text = ''
            [registries.search]
            registries = ['docker.io']
        '';
}
;}
