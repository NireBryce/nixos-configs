# 46. "Enabled" is a claim about config, not about who holds the port

_Last modified: 2026-09-09_

§46 of [lessons-learned.md](../lessons-learned.md#46-enabled-is-a-claim-about-config-not-about-who-holds-the-port) — that page keeps the one-line version of every lesson; this is §46's full account.

**Borrowed, not lived** — the one entry in this file that did not happen here.
Adopted from a NixOS Discourse thread while enabling avahi and
systemd-resolved together (2026-08-21, `nire/system/networking/`), kept
because the shape is one this file already keeps hitting and because it is
what the next `.local` bug on this fleet will look like.

The report: `.local` names failing to resolve while `resolvectl status` showed
mDNS enabled **both globally and per-interface**. Queries timed out with "All
attempts to contact name servers or networks failed" while avahi resolved the
same names on the same host; the suggested per-link `nmcli` fix changed
nothing; the thread closed unresolved.

mDNS is not a switch either daemon owns. It is a claim on UDP 5353, and only
one listener receives the unicast replies — so a daemon can be configured
correctly, report itself enabled, and answer nothing, because another process
holds the socket. **Neither daemon's status output mentions the other.**
`resolvectl status` will not say avahi has the port; `avahi-daemon` says so
only in its own journal. Which makes "is it enabled?" the wrong question and
"who holds 5353?" the right one:

```sh
sudo ss -ulpn 'sport = :5353'      # who actually has the socket
resolvectl mdns                    # what resolved thinks, per link
journalctl -u avahi-daemon | grep -i "another\|stack"
```

This tree settles the contention up front — resolved's `MulticastDNS = "no"`,
global rather than per-link so NetworkManager's own `connection.mdns` cannot
re-open it; the reasoning lives in `resolved.nix`/`avahi.nix`, not here. That
is a claim about config too — if `.local` misbehaves, check the socket before
concluding the Nix is wrong.

Same family as §1 (a tool reporting success has not thereby been tested), §22
(a zero is not evidence until you show the query can return non-zero) and §31
(a count is only evidence if you know what it counts), generalised: **a
configuration readout reports intent, and intent is exactly what is not in
question when two things contend for one resource.** When two components can
claim one resource, neither one's view of itself is diagnostic — go look at
the resource.
