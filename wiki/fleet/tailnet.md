# Managing the tailnet

_Last modified: 2026-11-09_

This fleet is tailnet-first: hosts reach each other, the NAS and cube's web
services over Tailscale (tailnet `moose-micro.ts.net`), and use the LAN as a
fallback. This page is the one place for how that is set up, who decides
whether a connection works, how to change the rules, and how to tell which
layer is failing. Other pages hold the parts: names in
[name-resolution](name-resolution.md), hosts in [hosts](hosts.md), service
names in [reverse-proxy](../config-structure/categories/reverse-proxy.md),
and the four traps in the header of
`flake/modules/general-config/system/networking/tailscale.nix`.

## Contents

- [Quick facts](#quick-facts)
- [How a connection is decided](#how-a-connection-is-decided)
- [The policy file](#the-policy-file)
- [Changing the policy](#changing-the-policy)
- [Tags](#tags)
- [Adding things](#adding-things)
- [Diagnosing](#diagnosing)
- [Not in the repo](#not-in-the-repo)
## Quick facts

| thing | answer |
|---|---|
| tailnet | `moose-micro.ts.net` |
| device names | `ts-<x>` (`ts-cube`, `ts-hive`, ...), set in the Tailscale admin console. `nire-<x>` never resolves over the tailnet. |
| who decides if a connection works | two layers: the tailnet policy's grants, then the destination's own firewall |
| tailnet policy | lives in Tailscale's control plane. `acl-diff-applied.hujson` in `homelab/reverse-proxy/tailscale-services/` is the repo's record of what was applied; editing it changes nothing live. |
| change the policy | `just tailscale-acl diff <file>`, then `just tailscale-acl apply <file>` |
| what the script needs | the sops key `tailscale_api_token`, which it extracts without printing |
| a port timing out while `tailscale ping` works | a missing grant, not a firewall (trap 2 in `tailscale.nix`) |
| tagged devices | `nire-cube` is `tag:homelab-cube`. A tagged device is not in `autogroup:members`, as a source or a destination. |
| names for a host | `just reach <x>` tries every name |

## How a connection is decided

A packet from one tailnet device to another passes two checks in order:

1. **The tailnet policy.** Tailscale drops the packet at the mesh layer
   unless a grant allows source, destination and port. The policy has no
   `acls` entries; everything is `grants`. A dropped packet gives a
   timeout, never a refusal.
2. **The destination's firewall.** On NixOS hosts `tailscale0` is a trusted
   interface (`networking.nix`, every Linux host), so a packet that passed
   the grant is accepted, and the grant alone decides which ports a tailnet
   device can reach. A device that is not a NixOS host, such as the NAS
   `ts-hive`, has its own firewall that applies as well.

So a new service on a tailnet device needs its port in the grant, in the same
change that adds the service. The policy comments say the same:
"a service reached over the tailnet on a member device needs its port here,
or it times out."

## The policy file

`acl-diff-applied.hujson` holds, in order: a group for golink admins, a host
alias for `ts-hive` (a grant destination cannot name a device, so it gets an
alias; re-check it if the NAS is ever re-registered), `tagOwners`,
`autoApprovers` for the `svc:` names cube advertises, and the `grants`.
It has no `ssh` block and no Funnel settings; both were removed 2026-09-26.
Read the file for the current ports instead of a copy of them here. The
grants fall into these groups:

- members to members, on the ports in use between ordinary devices;
- members to `tag:homelab-cube`, on the ports cube serves;
- members to each `svc:` name;
- `tag:homelab-cube` as a source: to the `svc:` names, and to `ts-hive`
  (`tcp:22` for restic, `udp:161` for SNMP).

## Changing the policy

1. Edit `acl-diff-applied.hujson` and open a PR as usual. The file is a
   record: nothing live changes yet.
2. Run `just tailscale-acl diff <path to the file>`. It compares the file
   with the live policy. Differences you did not make mean the live policy
   was edited in the console; reconcile them before applying.
3. Run `just tailscale-acl apply <same file>`. The change is live at once for
   every device.
4. Run the diff again. "No difference" means the repo and the tailnet agree.

The script extracts the one key `tailscale_api_token` from `secrets.yaml`
with sops. The decryption key on the hosts is the SSH host key, readable only
by root, so the script tries sops as you, then asks for sudo with a prompt on
the terminal. Run `just tailscale-acl` from an interactive shell. From a
session with no terminal, such as an agent's, it stops and says so (seen
2026-11-09); the user runs `diff` and `apply`. Never print the token, and never decrypt the whole file to
look for it (skill `secrets-hygiene`).

`svc:` service objects are a separate resource from the policy file. Use
`just tailscale-acl vip-get|vip-put|vip-delete svc:<name>`, with the `svc:`
prefix. Details and traps: the README in `tailscale-services/`.

## Tags

Tagging a device moves its ACL identity from the user to the tag. Two
consequences, both seen live:

- **As a destination** (2026-09-07): the device drops out of every other
  device's peer list the moment the tag takes effect, unless a grant already
  covers `tag:<name>` as a destination.
- **As a source** (2026-09-14, issue #298): the device gets no `svc:` DNS
  records, because every `svc:` grant had `autogroup:members` as its source.
  The first check is `tailscale status --json | jq .ExtraRecords` on the
  tagged host: `null` there while other devices list the records.

So tagging a device and its grants (both directions) are one change, never
staged. Apply a tag with `sudo tailscale up --advertise-tags=tag:<name>` on
the device; `tailscale set` has no such flag.

## Adding things

- **A port on an existing device:** add it to the matching grant, then apply.
- **A web service on cube:** skill `new-tailscale-service`, and the
  `reverse-proxy` category page. It needs a `svc:` object, a `serve.nix`
  entry, a Caddy vhost, an `autoApprovers` line and a grant, and they must
  agree on ports.
- **A device:** `sudo tailscale up` once, then name it `ts-<x>` in the admin
  console. Hosts that wipe `/root` keep their identity through
  `tailscale-persist.nix`. No auth key is wired in, because keys expire.
- **A tagged device:** the Tags section.

## Diagnosing

| symptom | first check |
|---|---|
| a port times out, `tailscale ping` works | the grant for that source, destination and port |
| `Could not resolve hostname nire-x` | use `ts-x`; see name-resolution |
| a name fails on one tagged host only | `ExtraRecords` on that host |
| the device vanished from every other peer's list | a tag without its destination grant |
| a name fails everywhere | is Tailscale up on the machine you are on; `just reach <x>` |
| a port is open on the LAN address and closed on the tailnet one | the grant, not the host |

Example, 2026-11-09: cube's SNMP poll of `ts-hive` timed out while
`tailscale ping` worked and the LAN address answered. The grant from
`tag:homelab-cube` to `ts-hive` allowed only `tcp:22`. Adding `udp:161`
fixes it once the policy is applied.

## Not in the repo

The admin console holds the device names, which devices carry which tag,
key expiry, DNS settings and the live policy. Key and credential expiry
dates are tracked with skill `maintenance-schedule`.
