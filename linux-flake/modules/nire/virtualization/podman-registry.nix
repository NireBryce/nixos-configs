{ self, inputs, ...}:
{ flake.homeModules.virtualization = # TODO: figure out how to make a hybrid flake-parts that interleaves home-manager and nixos
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
