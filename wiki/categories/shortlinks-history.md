# `shortlinks` — history

## Contents

- [The first switch crash-looped](#the-first-switch-crash-looped)
- [See also](#see-also)

The first-switch incident behind [shortlinks](shortlinks.md)'s
`AF_NETLINK` requirement, split out 2026-09-03 so that page stays about the
module as it works today. The setting itself, and why it stays, is still
on the main page's "`DynamicUser`, deliberately" section — this is only
the story of how it was found.

## The first switch crash-looped

`golink.service` crash-looped on `nire-cube` on its first real switch
(2026-08-24, generation 13):

```
tsnet: route ip+net: netlinkrib: address family not supported by protocol
```

A missing `AF_NETLINK` in the module's own `RestrictAddressFamilies`. It
shipped as "evaluates, not runtime-verified" (written from a darwin
session, which can't build an `x86_64-linux` toplevel), and broke for
precisely the reason its own hardening comment claimed to be guarding
against — the risk was named correctly, attached to the wrong knob. Same
family as [monitoring](monitoring.md)'s `grafana.service` first-switch
failure: a green evaluation and a read-back of the rendered unit both said
nothing ([`lessons-learned.md`](../lessons-learned.md) §37).

Fixed the same day and confirmed working end to end, after the fix and the
one-time login: `golink.service` `active (running)` at `NRestarts=0`, 0
failed units, tailnet device `go` up on a direct connection, and
`http://go/` answering `HTTP 200` from another tailnet host.
`NRestarts=0` was the load-bearing number rather than `active (running)`:
the original failure was a crash-loop, and a unit that has restarted eight
times also reports `active` in between.

## See also

- [shortlinks](shortlinks.md) — the module as it works today, including
  why `AF_NETLINK` stays in `RestrictAddressFamilies`.
- [monitoring](monitoring.md) — the same "green eval, silent artifact"
  first-switch failure shape, on Grafana.
