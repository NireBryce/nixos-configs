# Common commands

_Last modified: 2026-10-07_

Commands you need when something is in the way: streaming cube's desktop,
getting back in after the lock screen locks you out, reaching Sunshine's web
UI, deploying to cube. Run them from any tailnet device with ssh access to
`ts-cube`. How it's configured lives in the module headers linked from each
section.

## Contents

- [Quick facts](#quick-facts)
- [Stream cube's desktop](#stream-cubes-desktop)
- [Locked out of cube's lock screen](#locked-out-of-cubes-lock-screen)
- [Sunshine web UI and pairing a device](#sunshine-web-ui-and-pairing-a-device)
- [Deploy a change to cube](#deploy-a-change-to-cube)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

## Quick facts

| I want to... | Run |
|---|---|
| clear a lock-screen lockout now | `ssh ts-cube sudo faillock --user elly --reset` |
| see recorded failed unlocks | `ssh ts-cube faillock --user elly` |
| open Sunshine's web UI | `ssh -L 47990:localhost:47990 ts-cube`, then `https://localhost:47990` |
| check Sunshine is running | `ssh ts-cube systemctl --user is-active sunshine` |
| check the headless display is up | `ssh ts-cube cat /sys/class/drm/card1-HDMI-A-1/status` (`connected`) |
| deploy experimental to cube | `ssh ts-cube 'cd ~/nixos-configs && git pull --ff-only && just baseline && just boot' && ssh ts-cube sudo reboot` |

## Stream cube's desktop

In Moonlight, add `ts-cube` (or its tailnet IP). Use the tailnet name, not
`nire-cube`: Sunshine's ports are open on `tailscale0` only.

cube boots straight into Plasma with no monitor attached and locks the
session at once, so a stream opens on the lock screen. Unlock with elly's
password; the YubiKey isn't registered on cube. Quitting the app in Moonlight
locks the session again; closing Moonlight without quitting leaves it to the
2-minute idle lock.

Config: `host-config/cube/configuration/headless-display-cube.nix` (forced
HDMI-A-1 output, autologin) and `stream-lock-cube.nix` (lock policy, Sunshine
settings).

## Locked out of cube's lock screen

5 wrong passwords within 15 minutes and the lock screen refuses password
unlock for 10 minutes; even the right password is rejected until then. Either
wait it out, or clear it from another machine:

```sh
ssh ts-cube sudo faillock --user elly --reset
```

`sudo` asks for elly's password; sudo itself is not under the lockout. A
correct unlock does not clear earlier failures, they expire after 15 minutes,
so `faillock --user elly` can show old entries after a successful unlock. A
reboot also clears the record (`/run/faillock` is tmpfs).

Config: `host-config/cube/configuration/lockscreen-faillock-cube.nix`.

## Sunshine web UI and pairing a device

The web UI answers on localhost only. Tunnel to it:

```sh
ssh -L 47990:localhost:47990 ts-cube
```

then open `https://localhost:47990` and accept the self-signed certificate.
To pair a new device: start pairing in Moonlight, which shows a 4-digit PIN,
and enter it on the web UI's **PIN** tab.

Sunshine's settings page is read-only on cube, because its settings are
declared in Nix. The application list is still editable here.

## Deploy a change to cube

cube's checkout is `~/nixos-configs` on `experimental`. After a change lands:

```sh
ssh ts-cube 'cd ~/nixos-configs && git pull --ff-only && just baseline && just boot' && ssh ts-cube sudo reboot
```

`just baseline` first records what cube currently runs, which can't be
recovered once the old generation is collected. `boot` plus reboot rather
than `switch` when kernel parameters changed; `just switch` otherwise.

## What's verified here

As of 2026-10-07:

- The faillock lockout and reset were exercised in a NixOS VM test with the
  same PAM rules, as a non-root user. Not yet on cube.
- Streaming, the lock-on-start, the idle lock and the web-UI tunnel are
  configured but not yet run on cube.

## See also

- [hosts.md](../hosts.md) — `ts-<x>` vs `nire-<x>` names, which host runs what.
- [Reaching cube's services](reaching-services.md) — cube's web services.
