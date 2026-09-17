# Using the forge, for agents

_Last modified: 2026-09-16_

Condensed from [forgejo.md](forgejo.md), which keeps the reasoning and the
verification trail. Facts only here.

Forgejo on `nire-cube`, single-user, sqlite3, tailnet-only. Module design and
history: [../categories/git-forge.md](../categories/git-forge.md).

## Addresses — the two hostnames differ on purpose

| | |
|---|---|
| Web | `https://git.moose-micro.ts.net/` (short: `http://git/`) |
| Clone HTTPS | `https://git.moose-micro.ts.net/<user>/<repo>.git` |
| Clone SSH | `forgejo@ts-cube:<user>/<repo>.git` |

Web goes through Caddy on a Tailscale Services vhost, which needs the FQDN
for its certificate. Git-over-SSH bypasses Caddy entirely — cube's ordinary
`sshd`, port 22 — so it uses the short `ts-cube`. Separate Forgejo settings
(`ROOT_URL` vs `DOMAIN`). Copy clone URLs from the repo page.

## Accounts

- `elly` is **admin** — confirmed 2026-09-12 from Site Administration.
- **Unauthenticated `/api/v1/users/search` masks fields**: always
  `last_login: 0001-01-01T00:00:00Z` and `is_admin`/`active` false,
  regardless of truth. It cannot answer either question; reading it as an
  answer produced a wrong one twice. Don't re-derive from it.
- **Registration is closed** (`DISABLE_REGISTRATION = true`).
  `/user/sign_up` returns **200** with a "registration is disabled" body and
  no form fields — status code is not evidence here, read the page.

## Creating a repo

- **Push-to-create is OFF** — `git push` to a nonexistent repo fails
  `Forgejo: Push to create is not enabled for users.` (verified 2026-09-16,
  tenacity, SSH, as `elly`). Create it server-side first.
- Token: `/run/secrets/forgejo_api_key`, owner `elly`, mode `0400`, on all
  three Linux hosts since 2026-09-16 (`secrets/forgejo-api-key.nix`, the
  `system` category). No `sudo`, no interactive `sops -d`.
- `POST /api/v1/user/repos`, header `Authorization: token <key>`, body
  `{"name": …, "private": true, "auto_init": false}`. Then
  `git remote add origin forgejo@ts-cube:elly/<repo>.git` (short host — SSH
  bypasses Caddy).
- **CLIs**: `tea` is *Gitea's* client, works only via API compatibility;
  Forgejo's own is `forgejo-cli`/`fj`. **`fj` 0.6.0 has no `repo create`**
  (`tea repo create` does). Neither is installed on any host here; the raw
  API call needs nothing.

## SSH keys

`forgejo` is the account you SSH **to**, not the key's owner — it has no
keypair, and none is generated for it. One shared system account serves every
person; Forgejo identifies you by the key you present. Add your **public**
key in the web UI (Settings → SSH keys); Forgejo writes
`~forgejo/.ssh/authorized_keys` itself — never hand-edit it.

A real reader misread `forgejo@ts-cube` as "the forgejo user's key" three
times from these docs (2026-09-13), which is why it is stated this plainly.

A key added there authorizes `forgejo@ts-cube` **only**, not
`elly@ts-cube` — separate accounts, separate `authorized_keys`.

Any existing key works, including `sk-ssh-ed25519@openssh.com` (touch per
auth). For a dedicated key, `ssh-keygen -t ed25519 -f ~/.ssh/id_forgejo`,
then:

```
Host ts-cube
    User forgejo
    IdentityFile ~/.ssh/id_forgejo
    IdentitiesOnly yes
```

`IdentitiesOnly yes` matters — without it ssh offers every identity and a
wrong one can match first.

Verify with `ssh -T forgejo@ts-cube`: **a greeting that closes is success**
(no shell on that account). A password prompt means the key didn't take, and
would fail anyway — `PasswordAuthentication` is off fleet-wide.

**Exercised 2026-09-13** from tenacity: auth (greeting names the key) and a
real `git clone` over SSH, with a plain `~/.ssh/id_ed25519` and no
`ssh_config` block. **Push over SSH still untested** — the mirror is
read-only on the Forgejo side.

## Storage and backups

sqlite3 at `/var/lib/forgejo/`, with the repos and Forgejo's generated
secrets. Cube has a plain persistent root — survives reboots unconfigured.

Backed up since **2026-09-06** (#87): restic to the QNAP, with a real
restore that opened a complete database. **The live `.db` files under
`/var/lib/forgejo` are excluded from every snapshot on purpose** (a live
sqlite file can be mid-write); the restorable copy is
`/var/lib/restic-backups-cube-sqlite-staging`. Restoring the wrong path
yields a file that is present and opens as nothing.

## Mirroring

`elly/nixos-configs` is a real pull mirror of the GitHub repo, created
2026-09-11 (migrate API, `mirror: true`, `mirror_interval: 8h0m0s`,
`forgejo_api_key` sops secret). All 7 branches confirmed matching; default
branch `experimental`. **Mirror-or-origin is settled** — mirror, reaffirmed
2026-09-12. GitHub stays canonical.

## See also

- [forgejo.md](forgejo.md) — the reasoning and what was verified when.
- [../categories/git-forge.md](../categories/git-forge.md) — the module.
- [pending-setup.md](pending-setup.md) — item 1, the SSH key, still open.
