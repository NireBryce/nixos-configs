# Standalone home-manager configuration for elly on nire-durandal.
#
# "Standalone" means home-manager runs as its own tool (activated with
# `home-manager switch`), separate from NixOS. The alternative would be
# integrating it into the NixOS build via the home-manager NixOS module,
# but standalone lets you switch home config without a full system rebuild.
#
# The modules list works the same way as for NixOS:
#   every den.aspects.<name>.homeManager declaration in configs/ is
#   transposed by flake-aspects into flake.modules.homeManager.<name>,
#   and builtins.attrValues collects them all into the modules list here.
#
# extraSpecialArgs = inputs
#   Same purpose as specialArgs in lib.nix: makes all flake inputs available
#   as module arguments so home-manager modules can receive them by name.
#
# Switch with: nh home switch --configuration elly@nire-durandal ~/nixos/linux-flake/
#          or: home-manager switch --flake .#elly@nire-durandal
{ users.elly.homeManager =
{ inputs, config, ... }:
{
    flake.homeConfigurations."elly@nire-durandal" 
    = inputs.home-manager.lib.homeManagerConfiguration 
    {
        pkgs = inputs.nixpkgs.legacyPackages."x86_64-linux";
        extraSpecialArgs = inputs;
        modules = builtins.attrValues config.flake.modules.homeManager;
        
        # TODO: original is inputs.self.modules.nixos;
        imports = with inputs.self.modules.homeManager; [
            <elly.aliases>
            <elly.fonts>
            <elly.git>
            <elly.hm-settings>
            <elly.home-config>
            <elly.user>
            <packages.linux>
        ];
    };
}
;}
