---
name: maintenance-schedule
description: How to review and keep current wiki/maintenance-schedule.md, the fleet's key/credential expiry and rotation checklist.
---

# Tending the maintenance schedule

## Applies to

Any request to "check what's due", "review key expiry", or similar against
[wiki/maintenance-schedule.md](../../../wiki/maintenance-schedule.md); also
triggers any time a change introduces or rotates a credential, key, or
certificate with an expiry, rotation cadence, or silent-breakage property —
that page needs a matching update in the same change, the same discipline
`wiki-sync` asks for elsewhere. Not for the secret *values* themselves —
that's `secrets-hygiene`.

## Why this exists

`tailscale_key` sat in `secrets.yaml` past its 90-day validity, unused,
because nothing prompted anyone to look at it again after the flake-parts
port. A credential with an expiry that nobody is looking at is
indistinguishable from one that doesn't exist until it fails — usually as a
service going unreachable with no matching commit to explain why. The page
exists so "is anything about to expire" has one place to check instead of
re-deriving it from `secrets.yaml` and module comments each time.

## Reviewing the page

1. **Read `wiki/maintenance-schedule.md` in full** — it's short by design;
   don't grep for one item when reviewing.
2. **For each item, check its actual current state** where that's possible
   without decrypting anything unnecessary:
   - A live check (Tailscale admin console, a service's own settings page)
     beats inferring from repo state.
   - A `secrets.yaml` key's *existence* is fine to check (`grep '^key-name:'
     secrets.yaml`); its *value* is not needed to know whether it's
     rotated — follow `secrets-hygiene` if a value genuinely must be read.
   - Some items (SSH host key pins, Syncthing certs) have no live check
     worth doing on a routine pass — the page says so; don't invent one.
3. **Update each item's "Last checked" date** to today, whether or not
   anything changed. An unchanged date is what makes a stale item visible
   later.
4. **If something is actually due** (an expired or soon-to-expire key, a
   credential overdue for rotation): follow that item's linked procedure
   (`backup-runbook.md`'s rotating-the-secrets section, for example) rather
   than improvising a new one, and use `secrets-hygiene` practices while
   doing the rotation itself. Update the item's rotation-history line
   afterward.
5. **If a status changed from "pending"/"unverified" to something concrete**
   (Grafana credentials finally set, a Tailscale admin-console setting
   confirmed) — update the item's own text, not just the date, so the page
   doesn't keep saying "pending" past the point it's true.

## Adding a new item

When a change introduces a new credential, key, or certificate with an
expiry, rotation cadence, or silent-breakage property, add a row to
`maintenance-schedule.md` in the *same* change — see that page's own
"Adding a new item" section for the shape (what/expiry/procedure or
recommendation/last checked) and what does *not* qualify (a secret with no
such property just lives in `secrets.yaml`, no row needed).

## Don't sops-encrypt this file

`maintenance-schedule.md`'s own "Why this file is plaintext" section has
the reasoning: key names, dates, and durations aren't the secret values
themselves, and encrypting a page meant to be checked on a cadence works
against its purpose. That judgment is per-row, not per-file — if a future
row would need to hold real key material to be useful, encrypt *that
value* with sops and reference it, don't wrap the whole page in ciphertext.
Don't reverse this call without re-reading that section; it's not an
oversight to "fix".

## See also

- [wiki/maintenance-schedule.md](../../../wiki/maintenance-schedule.md) —
  the page itself.
- `secrets-hygiene` skill — how to check or touch the underlying secrets
  without printing plaintext.
- `wiki-sync` skill — the general discipline this skill specializes for
  one page.
- `homelab/backup-runbook.md`'s "Rotating the secrets" section — the
  worked example of an actual rotation procedure this page points at
  rather than duplicates.
