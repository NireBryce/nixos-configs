# sshd on tenacity answers over the tailnet only, never on whatever LAN or
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
{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.nixos.${moduleName} = {
        # # description = "tenacity: sshd reachable over tailscale0 only";
        services.openssh.openFirewall = false;
    };
}
