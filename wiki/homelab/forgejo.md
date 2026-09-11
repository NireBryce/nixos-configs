# Using the forge

_Last modified: 2026-09-11_

## Contents

- [Where it is](#where-it-is)
- [Signing in, and why there's no sign-up](#signing-in-and-why-theres-no-sign-up)
- [SSH keys, and the second user on this host](#ssh-keys-and-the-second-user-on-this-host)
- [Database and backups](#database-and-backups)
- [This repo is mirrored here](#this-repo-is-mirrored-here)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

[Forgejo](https://forgejo.org/) on `nire-cube`, at
`https://git.moose-micro.ts.net/` — its own Tailscale Services name as of
2026-09-07 (was `https://ts-cube.moose-micro.ts.net/git/`; that path 404s
now). This page is about **using** it — signing in, cloning, pushing. For
how it's configured and why its two hostnames disagree, see
[git-forge](../categories/git-forge.md).

## Where it is

| | |
|---|---|
| Web | `https://git.moose-micro.ts.net/` |
| Clone over HTTPS | `https://git.moose-micro.ts.net/<user>/<repo>.git` |
| Clone over SSH | `forgejo@ts-cube:<user>/<repo>.git` |

**Those two hostnames are different on purpose, and it isn't a typo.** Web
traffic goes through Caddy on Forgejo's own Tailscale Services vhost, which
needs the full FQDN for its certificate. Git-over-SSH does *not* go through
Caddy at all — it goes to cube's ordinary `sshd` on port 22 — so its clone
URLs use the short `ts-cube`. Forgejo builds each from a separate setting
(`ROOT_URL` and `DOMAIN`), which is why they can and do differ.

Copy clone URLs from the repo page rather than typing them; Forgejo generates
both correctly.

## Signing in, and why there's no sign-up

**Registration is closed.** `DISABLE_REGISTRATION = true` — a single-user
homelab forge on a tailnet only Elly's devices reach has nothing to gain from
open self-registration.

A detail that will mislead a status check: `/git/user/sign_up` returns **HTTP
200**, not a 403 or a redirect. The page renders "Registration is disabled.
Please contact your site administrator." with no form fields on it. Verified
live, 2026-08-24. So "the signup page loads" is not evidence registration is
open — read the page, not the status code.

**The first account (`elly`, admin) is bootstrapped automatically as of
2026-08-26** — `forgejo-admin-bootstrap` (see
[git-forge](../categories/git-forge.md)) creates it on activation, with a
password from this repo's sops secrets rather than typed by hand. It
resets that password to the sops value on every `switch`, so changing it
through the web UI won't stick — change it in `secrets.yaml` instead if it
ever needs to change. **Switched and logged in, confirmed 2026-09-05**;
whether the account is genuinely *admin* is still unconfirmed (see
[git-forge](../categories/git-forge.md)'s account of the masked-field
trap).

To add a *second* user, on cube:

```sh
sudo -u forgejo forgejo admin user create --help
```

`--admin`, `--username`, `--email` and `--password` are the flags that
matter. Run `--help` rather than trusting a command line from this page —
nothing here has created a second user, so the exact invocation is
untested.

## SSH keys, and the second user on this host

Forgejo manages `~forgejo/.ssh/authorized_keys` itself as keys are added
through the web UI (Settings → SSH keys). Cube's own `sshd` does the rest
with ordinary per-user `authorized_keys` lookup — there's no
`AuthorizedKeysCommand` and no second SSH daemon on a second port.

Two consequences:

- **Git-over-SSH rides on port 22**, which is already open on the LAN as well
  as the tailnet, on every NixOS host here. This module didn't add a port; it
  added a user (`forgejo`) that can authenticate to the sshd that was already
  reachable.
- **A key added in the web UI takes effect for `forgejo@ts-cube`, not for
  `elly@ts-cube`.** They're separate accounts with separate
  `authorized_keys`; adding one doesn't grant the other.

## Database and backups

sqlite3, at `/var/lib/forgejo/`, along with the repos themselves and the
secrets Forgejo generates on first run. Cube has a plain persistent root, so
this survives reboots with nothing special configured.

**There is no backup of any of this.** Nothing in this repo backs
`/var/lib/forgejo` up anywhere — verified 2026-08-24 by grepping the whole
tree for backup tooling, which found none — and a homelab forge with one copy
of a repo is a repo you have one copy of. Push anything you care about
somewhere else as well, or treat this as a mirror rather than an origin,
until [#87](https://github.com/NireBryce/nixos-configs/issues/87) lands.

## This repo is mirrored here

`elly/nixos-configs` — `https://git.moose-micro.ts.net/elly/nixos-configs`
— is a real Forgejo pull mirror of
`https://github.com/NireBryce/nixos-configs.git`, created 2026-09-11 via
the migrate API (`mirror: true`, `mirror_interval: 8h0m0s`) using the
`forgejo_api_key` sops secret. GitHub stays canonical; Forgejo re-pulls on
its own schedule. Confirmed live: all 7 branches present and matching
GitHub's own branch list, default branch `experimental`. This is the first
repo actually pushed/mirrored here — see
[pending-setup.md](pending-setup.md) item 2.

## What's verified here

Exercised against the live instance on 2026-08-24 from `nire-lysithea`, over
the tailnet, against the now-retired `ts-cube.../git/` path: `HTTP 200` over
validated TLS with Forgejo's own page title, `/explore/repos` and
`/user/login` both 200, `/user/sign_up` 200 with the registration-disabled
text and no form fields. Re-verified 2026-09-11 against the current
`git.moose-micro.ts.net` hostname: root, `/explore/repos`, and `/user/login`
all still 200.

**Not exercised:** adding an SSH key, or a clone/push over SSH specifically
(the mirror above was created and synced entirely over HTTPS via the API).
The SSH clone URL shape comes from the module's `DOMAIN` setting and
Forgejo's own behaviour, not from a clone run here.

## See also

- [git-forge](../categories/git-forge.md) — the module, the zero-touch secret
  handling, and why `DOMAIN` and `ROOT_URL` disagree.
- [Reaching cube's services](reaching-services.md) — the URL map and what to
  check when something doesn't answer.
- [system](../categories/system.md) — `ssh.nix`, the host sshd git+ssh rides
  on.
