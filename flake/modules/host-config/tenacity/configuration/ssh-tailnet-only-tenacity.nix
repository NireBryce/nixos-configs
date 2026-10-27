# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: sshd on tenacity answers over the tailnet only, never on whatever LAN or
# café wifi the handheld is on that day. Added 2026-09-26.
#
# Closes only the firewall port: sshd still listens on every address, and
# `tailscale0` is in networking.nix's trustedInterfaces, so tailnet peers
# reach it with no rule of their own. `ssh ts-tenacity` works;
# `ssh nire-tenacity.local` from the LAN now times out. `just reach
# tenacity` tries both, so it keeps working.
#
# networking.nix deliberately does not list 22 itself, so this one option
# is the whole switch. If Tailscale is down on tenacity, nothing can ssh in
# -- use the machine's own console.
{
    nixos = {
        services.openssh.openFirewall = false;
    };
}
