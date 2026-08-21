# Sunshine game-stream host (Moonlight's server side).
#
# Filed alongside gaming.nix rather than as its own category: this directory
# is collected into the `system` category same as gaming.nix is, and `system`
# is imported whole by every NixOS host (see CLAUDE.md, "Membership is
# implicit"), so this reaches all five hosts -- durandal, cube and testbed
# (workstations) as well as tenacity and lego (handhelds) -- with no
# per-host wiring. That is deliberate: streaming a session off a handheld is
# as legitimate a use as streaming to one.
#
# openFirewall is deliberately NOT set. Sunshine's pairing handshake and its
# native HTTP/RTSP/UDP parsing are real attack surface -- a paired client gets
# full remote control (keyboard, mouse, screen), gated only by a 4-digit PIN --
# and `openFirewall = true` would open that on every interface, not just
# trusted ones. For the two handhelds especially, that means whatever wifi
# tenacity or lego happen to be on that day, not just home. `tailscale0` is
# already in `networking.firewall.trustedInterfaces` (see networking.nix), so
# Sunshine is reachable over the tailnet with no firewall rule needed here --
# a device has to already be authenticated onto the tailnet before it can
# reach Sunshine's ports at all, which is a stronger gate than anything
# achievable by putting auth in front of a protocol that is only half HTTP
# (the stream itself is raw UDP, so a web-auth reverse proxy wouldn't cover
# it). Tailscale ACLs, configured in the tailnet admin console rather than
# here, can narrow this further to specific devices if that's ever wanted.
#
# Hardware encode: nothing to set here. `capSysAdmin` (below) covers KMS
# screen *capture*; the actual *encode* is VAAPI, which comes from
# `hardware.graphics.enable` -- already `true` on all four AMD hosts via
# nire/hardware/amd/amdgpu/amdgpu.nix (mesa's radeonsi driver bundles VAAPI,
# no separate package needed the way Intel's does). This module deliberately
# does not force `services.sunshine.settings.encoder = "vaapi"`: sunshine
# already prefers a hardware encoder when one is usable and falls back to
# software (x264) otherwise, and forcing the setting would trade that graceful
# fallback for a hard failure on any host where VAAPI turns out not to work --
# not a trade worth making on config that has not been runtime-tested yet (see
# CLAUDE.md, "undated verified means evaluates"). The device permissions VAAPI
# and KMS capture both need at runtime (`render`, `video`, `uinput`) are in
# sunshine-elly.nix, right next to this file -- they edit the user account,
# not the service, so they're split out rather than living here.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { ... }: {
            # # description = "Sunshine: host a Moonlight game-stream session, reachable only over Tailscale";
            services.sunshine = {
                enable      = true;
                autoStart   = true; # runs as a systemd user service, not launched by hand
                capSysAdmin = true; # KMS screen capture without running the service as root
                # openFirewall deliberately omitted -- see header.
            };
        };
}
