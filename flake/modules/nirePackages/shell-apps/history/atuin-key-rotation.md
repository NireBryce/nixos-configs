# Rotating the Atuin account encryption key

> **Written by Claude Code.** A working note, not documentation.

Atuin's sync server is zero-knowledge: it only ever stores history
encrypted with your key and never sees the key itself. That means there is
**no server-side "rotate" operation** — as of writing, no `atuin key
rotate` command exists. Regenerating the local key
(`~/.local/share/atuin/key`, symlinked in via `config.toml` next to this
file) only changes what *this machine* uses going forward; every entry
already pushed to the server stays encrypted under the *old* key. Rotating
the key that protects the whole account means wiping the server copy and
re-uploading everything under a new one.

## Procedure

1. **Back up the current key** first, in case anything needs recovering
   before the rotation finishes:
   ```sh
   atuin key
   ```
2. **Wipe the server-side history.** Irreversible, no confirmation
   prompt — local history is untouched:
   ```sh
   atuin account delete
   ```
3. **Register fresh** — this mints a new key:
   ```sh
   atuin register
   ```
4. **Push local history back up**, now encrypted under the new key:
   ```sh
   atuin sync
   ```
5. **On every other device**, install the new key (`atuin key`) *before*
   it syncs again — otherwise it'll try decrypting new entries with the
   stale one and throw "attempting to decrypt with incorrect key".

## Cadence

No fixed schedule; rotate on suspicion of key compromise (e.g. a device
the key lived on is lost or stolen). Not time-boxed like the Tailscale
items in [`maintenance-schedule.md`](../../../../../wiki/maintenance-schedule.md).

## Watch for

Atuin's PASETO/PASERK-based encryption scheme (announced on their blog)
is designed to make rotation cheaper — re-wrapping a small data-encryption
key instead of re-encrypting every history line — but that's an
architectural improvement, not an exposed command yet. If a real
`atuin key rotate` ships, steps 2–4 above collapse into one and this file
should be updated to say so.
