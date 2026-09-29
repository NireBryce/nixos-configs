# Using the forge, for agents

_Last modified: 2026-09-29_

Condensed from [forgejo.md](forgejo.md). Forgejo on `nire-cube`, single-user,
sqlite3, tailnet-only. Module: [../categories/git-forge.md](../categories/git-forge.md).

## Addresses

| | |
|---|---|
| Web | `https://git.moose-micro.ts.net/` (short: `http://git/`) |
| Clone HTTPS | `https://git.moose-micro.ts.net/<user>/<repo>.git` |
| Clone SSH | `forgejo@ts-cube:<user>/<repo>.git` |

Web = Caddy Tailscale Services vhost (FQDN for cert; `ROOT_URL`). SSH bypasses
Caddy: cube's `sshd`, port 22, short name (`DOMAIN`). Copy clone URLs from the repo page.

## Accounts

- `elly` is **admin** (confirmed 2026-09-12, Site Administration).
- Unauthenticated `/api/v1/users/search` masks fields (`last_login: 0001-01-01T00:00:00Z`,
  `is_admin`/`active` false always): answers neither question.
- Anonymous access off since 2026-09-26 (`REQUIRE_SIGNIN_VIEW`): browsing, API, HTTPS clones need login or token.
- Registration closed (`DISABLE_REGISTRATION = true`). `/user/sign_up` returns **200**
  with a "registration is disabled" body, no form: read the page, not the status.

## SSH keys

- `forgejo` is the account you SSH **to**, not a key owner; no keypair. One shared
  system account for everyone; Forgejo identifies you by the key presented.
- Add your **public** key in web UI (Settings → SSH keys). Forgejo writes
  `~forgejo/.ssh/authorized_keys`: never hand-edit. sshd reads it only via
  `forgejo.nix`'s `Match User forgejo`; home-dir key files off for all other accounts (`ssh.nix`).
- Authorizes `forgejo@ts-cube` only, not `elly@ts-cube`.
- Any key works, incl. `sk-ssh-ed25519@openssh.com`. Dedicated: `ssh-keygen -t ed25519 -f ~/.ssh/id_forgejo`, then:

```
Host ts-cube
    User forgejo
    IdentityFile ~/.ssh/id_forgejo
    IdentitiesOnly yes
```

- `IdentitiesOnly yes` needed: else ssh offers every identity, a wrong one may match first.
- Verify `ssh -T forgejo@ts-cube`: a greeting that closes = success (no shell). Password
  prompt = key didn't take (`PasswordAuthentication` off fleet-wide).
- Exercised 2026-09-13 from tenacity: auth and `git clone` over SSH with plain
  `~/.ssh/id_ed25519`, no `ssh_config` block. **Push over SSH untested** (mirror read-only).

## CI (Forgejo Actions)

- Runner: libvirt guest `forge-runner` on cube, live since 2026-09-25.
- Workflows: `.forgejo/workflows/*.yaml`, GitHub-Actions syntax.
- `runs-on: nix` (runner label `nix:host`: name `nix`, executor `host`); `runs-on: nix:host`
  waits forever. Job runs inside the VM with its nix in `PATH`. No container runtime:
  `container:` jobs and `docker://` actions find no runner.
- Runs: repo **Actions** tab; runner under Site Administration → Actions → Runners.
  New repos default Actions OFF (`DEFAULT_REPO_UNITS`): Settings → Repository → Units.
- Runner scope `elly` (that user's repos), `capacity = 1`, no actions cache server.
  Fresh VM + single-use registration per job (`forge-runner-cycle`): no state between
  jobs, cold nix store, ~20–40 s boot; a `forge-runner` row per job, deleted on completion.
- See [pending-setup.md](pending-setup.md) item 8, [practice-environment.md](practice-environment.md).

## Branch protection

Per repo: Settings → Branches → Add new rule; pattern `main`.

- Push: **Whitelist restricted push** (users: `elly`) or **Disable push** (PR-only).
  NOT **Enable push**: admits anyone with write, incl. the Actions job token, so a workflow
  could push. Whitelist checks listed user/team IDs only; Actions user never in it
  (`models/git/protected_branch.go` `CanUserPush`). Deploy-key whitelist off unless needed.
- **Enable status check**: pattern on contexts `<workflow> / <job> (<event>)`
  (`services/actions/commit_status.go`), e.g. `ci / *`. Context appears in picker only after a run.
- **Required approvals**: no self-approve; single account ⇒ 0, or 1 with a second account
  ([practice-environment](practice-environment.md#the-review-gap)). With approvals:
  **Dismiss stale approvals** and **Block merge if pull request is outdated** on.
- **Enforce this rule for repository admins**: on (`elly` is admin).
- **Require signed commits**: only if all committers sign. Merge whitelist: off.
- Workflows: `pull_request`, not `pull_request_target` (runs base code with base
  token/secrets for fork PRs). No Actions secrets in repos that don't need them.

## Storage and backups

- sqlite3 at `/var/lib/forgejo/` with repos and generated secrets. Cube has persistent root.
- Backed up since 2026-09-06 (#87): restic to the QNAP; restore verified (opened a complete DB).
- **Live `.db` files under `/var/lib/forgejo` are excluded from every snapshot on purpose**;
  restorable copy is `/var/lib/restic-backups-cube-sqlite-staging`. Wrong path restores a file that opens as nothing.

## Mirroring

`elly/nixos-configs` is a pull mirror of the GitHub repo (created 2026-09-11; migrate API,
`mirror: true`, `mirror_interval: 8h0m0s`, `forgejo_api_key` sops secret). All 7 branches
matched; default branch `experimental`. GitHub stays canonical; mirror-not-origin settled 2026-09-12.

## See also

[forgejo.md](forgejo.md) · [../categories/git-forge.md](../categories/git-forge.md) ·
[pending-setup.md](pending-setup.md) (item 1, SSH key, still open)
