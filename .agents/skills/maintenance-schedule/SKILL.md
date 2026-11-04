---
name: maintenance-schedule
description: Reviews and updates the checklist of key and credential expiry and rotation dates.
when_to_use: Asked what's due, to review key expiry, or when a change adds or rotates a key, credential or certificate that expires.
---

# Tending the maintenance schedule

## Applies to

Use this skill when asked to "check what's due", "review key expiry", or
similar against
[wiki/upkeep-and-admin/maintenance-schedule.md](../../../wiki/upkeep-and-admin/maintenance-schedule.md).
Also use it for any change that introduces or rotates a credential, key, or
certificate with an expiry, a rotation cadence, or a silent-breakage property:
update the page in the same change (`wiki-sync`). Secret *values* are out of
scope (`secrets-hygiene`).

## Why

`tailscale_key` sat in `secrets.yaml` past its 90-day validity, unused,
because nothing prompted a re-check after the flake-parts port. An expiring
credential that nobody watches looks absent until it fails, usually as an
unreachable service with no matching commit. The page is the one place to
check, so you do not have to re-derive the list from `secrets.yaml` and module
comments.

## Reviewing the page

1. **Read `wiki/upkeep-and-admin/maintenance-schedule.md` in full.** It is
   short; do not grep for one item.
2. **Check each item's current state** without decrypting more than needed:
   - Prefer a live check (Tailscale admin console, a service's settings page)
     to inferring from repo state.
   - A `secrets.yaml` key's existence is checkable with
     `grep '^key-name:' secrets.yaml`. You do not need its value to know
     whether it was rotated (otherwise see `secrets-hygiene`).
   - Some items (SSH host key pins, Syncthing certs) have no worthwhile live
     check on a routine pass. The page says so; do not invent one.
3. **Set each item's "Last checked" to today**, changed or not. An unchanged
   date is what makes staleness visible.
4. **If something is due** (expired, soon to expire, or overdue for rotation),
   follow the item's linked procedure (for example `backup-runbook.md`'s
   "Rotating the secrets"). Use `secrets-hygiene` while rotating, and update
   the rotation-history line.
5. **If an item's status moved from "pending"/"unverified" to concrete**,
   update the item text, not only the date.

## Default credentials are a live credential, not a missing one

Do not word a stock-credential row as an absence ("still on initial setup",
"pending", "not yet configured"). A service shipping stock credentials has a
working admin account now, its password is in public vendor docs, and anyone
who can reach the service has it. On 2026-09-13 the user read item 8
(Grafana), which said "still on initial/default setup ... hasn't had its
one-time setup done", as *unset* rather than *default and live*. The wording
was accurate and still misleading.

A stock-credential row states, in order:

1. The account is live and the password is publicly known (`admin`/`admin` or
   the vendor's, in those words).
2. What it grants (admin on which service, holding what).
3. What is in front of it (tailnet, LAN, firewall rule). This is the entire
   mitigation; name it.
4. What closes it, and that this needs a live check: a stock password is
   invisible from config (the absence of an `admin_password` setting is what
   leaves it stock).

Two traps:

- **Declaratively-set and left-at-default credentials look identical in
  `secrets.yaml`** (both absent). Check the module for an
  `admin_password`-shaped setting, not the secret store. Forgejo's admin
  password is a sops secret (item 7, `forgejo-admin-bootstrap`). Grafana's
  (item 8) was set by hand in the UI on 2026-09-13; `grafana-admin-password`
  in sops is separate and is applied at first start only, so it is never
  consumed (the admin user predates it). Read item 8 before wording anything
  about it.
- **"Not yet rotated since initial setup" is a different, acceptable
  status:** a real credential exists and has never changed (item 7). Keep the
  two wordings distinct.

## Adding a new item

Add a row in the same change. The page's own "Adding a new item" section has
the shape (what, expiry, procedure or recommendation, last checked) and says
what does not qualify: a secret with no expiry, rotation or silent-breakage
property just lives in `secrets.yaml`.

## Don't sops-encrypt this file

The page's "Why this file is plaintext" section has the reasoning: key names,
dates and durations are not secret values, and encrypting a page meant for
cadence checks defeats its purpose. Decide per row: if a row would need real
key material, sops-encrypt that value and reference it, not the whole page.
The plaintext is intentional; re-read that section before changing it.

## See also

- [wiki/upkeep-and-admin/maintenance-schedule.md](../../../wiki/upkeep-and-admin/maintenance-schedule.md): the page.
- `secrets-hygiene`: touch secrets without printing plaintext.
- `wiki-sync`: the general discipline this specializes.
- `homelab/backup-runbook.md` "Rotating the secrets": the worked rotation procedure this page points to.
