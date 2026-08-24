# Self-hosted booking: Easy!Appointments vs LibreBooking

**Status: evaluated 2026-08-24, nothing built, nothing decided beyond "not
now."** Elly's call was to write the conclusions down rather than start
work. This is a record so the comparison doesn't get re-derived from
scratch if it's ever picked up again — not a plan, and not a commitment
that a booking service is wanted on any host.

All version/activity figures below were checked on 2026-08-24 via the
GitHub API and are stale by definition. Re-check before leaning on them.

## The shape difference, which is the whole decision

The two projects sound like competitors and aren't:

| | Easy!Appointments | LibreBooking |
|---|---|---|
| Books | **a person's time** (service x provider x customer) | **a thing** (room, machine, vehicle, instrument) |
| Public flow | unauthenticated customer picks a slot on a public page | users generally need accounts; org-internal tool |
| Lineage | original project, CodeIgniter | fork of Booked Scheduler's last OSS release (2020), phpScheduleIt lineage, since diverged |
| License | GPL-3.0 | GPL-3.0 |
| Stars / open issues | 4.3k / 165 | 791 / 57 |
| Releases | 1.6.0 (2026-05-27), 1.6.1-alpha.1 (2026-08-19) | v5.1 -> v5.2 -> v5.3, monthly through 2026-08-03 |
| Last commit | 2026-07-29 | 2026-08-24 |

Both are actively maintained PHP/MySQL apps. Neither is abandoned; the
choice is about what you're booking, not about project health.

### Easy!Appointments

Pros: purpose-built for "someone books an appointment with you" —
services, providers, working plans, breaks, unavailabilities, email
notifications, Google Calendar sync, REST API (ships `openapi.yml`),
multi-language. Much bigger user base, so more written-down answers exist.
Simplest install of the two; setup wizard.

Cons: 165 open issues, and the release cadence is slower than the version
numbers suggest (1.6.1 was still alpha on 2026-08-19). Thin permissions
model. No payments, no CalDAV. There is a `premium` upsell tier, so some
features are deliberately not in the OSS build.

### LibreBooking

Pros: genuinely richer — role-based access control, quotas and credits,
waitlists, recurring reservations, granular usage reporting, ICS feeds for
Outlook/Thunderbird, plugin architecture, and real auth backends (LDAP, AD,
SAML, OAuth2). Monthly releases. Bootstrap 5, so no longer the 2020 Booked
look.

Cons: heavier and older underneath. **Apache is the supported web server**
— upstream says nginx "may work with proper configuration" but is not
officially supported, which matters because nginx + php-fpm is what this
tree would reach for by default. Needs PHP 8.2+ with a long extension list
and MySQL 8.0+ / MariaDB 10.6+. Wrong tool entirely for a public "pick a
slot with me" page — you'd be modelling yourself as a bookable resource and
fighting the account model.

### Conclusion reached

- Booking **your time** with outside people -> Easy!Appointments.
- Booking **shared resources** among people with accounts -> LibreBooking,
  and it's the better-maintained codebase of the two right now.

Elly's stated direction on 2026-08-24 was Easy!Appointments, as one of the
hosted services, before deciding not to pursue it for now.

## What it would cost to actually deploy either here

**Neither is in nixpkgs.** Checked against this repo's pinned nixpkgs
(`f13ff45`): no `librebooking`, no `easyappointments`, no
`easy-appointments`, and no `services.*` NixOS module for either. So this
is a `golink`-shaped job — hand-written `systemd.services.*`, the same
situation `nire/shortlinks/` documents — except worse in one specific way:

**Both are PHP webapps that expect a writable install directory.** E!A's
setup wizard writes `config.php`; both want mutable storage. That fights
the read-only store directly, and is the part that would need designing
rather than copying from an existing module here. On top of it you'd be
standing up MariaDB and php-fpm.

Given `nire-cube` already imports the `containers` category and both
projects publish Docker/compose setups, **a podman quadlet is probably
less work and less breakage than a hand-written module**, and it sidesteps
the writable-install-dir problem cleanly. That question — container vs
hand-written module — was raised and never answered; it's the first thing
to settle if this restarts.

Exposure would follow the existing tailnet-only pattern either way (see
`wiki/categories/monitoring.md` for Grafana and
`wiki/categories/git-forge.md` for Forgejo), not a new mechanism.

## The adjacent category, since it came up

If the real want is ever "here's my link, grab 30 minutes" rather than
"customers book a service slot," that's the Calendly-shaped category:
availability *derived* from live two-way calendar sync, plus buffers,
minimum notice, timezone detection, round-robin. Easy!Appointments is a
different model — you declare a working plan (Mon-Fri 9-5) and it doesn't
know you're busy unless the conflict lives in E!A or arrives through its
per-provider Google Calendar sync (Google only, no CalDAV).

Cal.com is the obvious name there. Two things worth recording because they
were got wrong from memory once already in the conversation this doc came
out of: **it is self-hostable, and its LICENSE is MIT** (read on
2026-08-24 — not AGPL, which is what an older memory of the project
says). The caveats are that it's heavy for a homelab — Next.js monorepo,
Postgres, Prisma — not in nixpkgs, and the official `calcom/docker` repo
has been **archived since 2025-10-29**, so self-hosting means following
upstream's own docs rather than a maintained compose file. Not evaluated
beyond that.

## Sources

- <https://github.com/alextselegidis/easyappointments>
- <https://github.com/LibreBooking/librebooking>
- <https://awesome-selfhosted.net/tags/booking-and-scheduling.html>
- <https://talos.tools/blog/5-best-self-hosted-booking-scheduling-apps>
