---
name: maintenance-schedule
description: How to review and keep current the fleet's key/credential expiry and rotation checklist.
when_to_use: Asked to "check what's due", "review key expiry", or any change that adds or rotates a key, credential, or certificate with an expiry.
---

# Tending the maintenance schedule

## Applies to

Requests to "check what's due", "review key expiry", or similar against [wiki/maintenance-schedule.md](../../../wiki/maintenance-schedule.md); also any change that introduces or rotates a credential, key, or certificate with an expiry, rotation cadence, or silent-breakage property — the page needs a matching update in the same change (`wiki-sync` discipline). Not for secret *values* (`secrets-hygiene`).

## Why

`tailscale_key` sat in `secrets.yaml` past its 90-day validity, unused, because nothing prompted a re-look after the flake-parts port. An unwatched expiring credential looks like a nonexistent one until it fails, usually as an unreachable service with no matching commit. The page is the one place to check instead of re-deriving from `secrets.yaml` and module comments.

## Reviewing the page

1. **Read `wiki/maintenance-schedule.md` in full** (short by design); don't grep for one item.
2. **Check each item's actual current state** without decrypting more than needed:
   - Live check (Tailscale admin console, a service's settings page) beats inferring from repo state.
   - A `secrets.yaml` key's *existence* is checkable (`grep '^key-name:' secrets.yaml`); its value isn't needed to know if it's rotated (else `secrets-hygiene`).
   - Some items (SSH host key pins, Syncthing certs) have no worthwhile live check on a routine pass; the page says so; don't invent one.
3. **Set each item's "Last checked" to today**, changed or not — an unchanged date is what makes staleness visible.
4. **If something is due** (expired/soon-expiring, overdue rotation): follow the item's linked procedure (e.g. `backup-runbook.md`'s "Rotating the secrets"), don't improvise; use `secrets-hygiene` while rotating; update the rotation-history line.
5. **If status moved from "pending"/"unverified" to concrete**, update the item text, not just the date.

## Default credentials are a live credential, not a missing one

Never word a stock-credential row as an absence ("still on initial setup", "pending", "not yet configured"). A service shipping stock credentials has a working admin account now, its password is in public vendor docs, and anyone who can reach the service has it. Precedent: `maintenance-schedule.md` item 8 (Grafana) once said "still on initial/default setup ... hasn't had its one-time setup done", and the user read it as *unset* rather than *default and live* (2026-09-13). Accurate, still misleading.

A stock-credential row states, in order:

1. The account is live and the password publicly known (`admin`/`admin` or the vendor's, in as many words).
2. What it grants (admin on which service, holding what).
3. What is in front of it (tailnet, LAN, firewall rule) — the entire mitigation; name it.
4. What closes it, and that this needs a live check: a stock password is invisible from config (absence of an `admin_password` setting is what leaves it stock).

Traps:

- **Declaratively-set and left-at-default credentials look identical in `secrets.yaml`** (both absent). Check the module for an `admin_password`-shaped setting, not the secret store. Forgejo's admin password is a sops secret (item 7, `forgejo-admin-bootstrap`); Grafana's (item 8) was set by hand in the UI 2026-09-13, and `grafana-admin-password` in sops is separate: applied at first start only, so never consumed (the admin user predates it) — read item 8 before wording anything about it.
- **"Not yet rotated since initial setup" is a different, fine status**: a real credential exists, never changed (item 7). Don't collapse the two wordings.

## Adding a new item

Add a row in the *same* change; the page's own "Adding a new item" section has the shape (what/expiry/procedure or recommendation/last checked) and what doesn't qualify (a secret with no expiry/rotation/silent-breakage property just lives in `secrets.yaml`).

## Don't sops-encrypt this file

The page's "Why this file is plaintext" section has the reasoning: key names, dates, durations aren't secret values, and encrypting a page meant for cadence checks defeats it. Judgment is per-row: if a row would need real key material, sops-encrypt *that value* and reference it, not the whole page. Not an oversight to "fix"; re-read that section before reversing.

## See also

- [wiki/maintenance-schedule.md](../../../wiki/maintenance-schedule.md) — the page.
- `secrets-hygiene` — touch secrets without printing plaintext.
- `wiki-sync` — the general discipline this specializes.
- `homelab/backup-runbook.md` "Rotating the secrets" — worked rotation procedure this page points to.
