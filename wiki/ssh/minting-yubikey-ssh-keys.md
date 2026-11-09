# Minting a YubiKey SSH key

_Last modified: 2026-11-08_

Runsheet for creating an SSH key on a YubiKey and authorizing it on the fleet.
Two routes: a FIDO2 resident key (section 1, the default) and a PIV key
(section 2). Run it for a first key, a second or backup key, or a replacement.

What is already configured: [yubikey.nix](../../flake/modules/general-config/system/security/yubikey.nix)
enables `pcscd`, the YubiKey udev rules, `yubikey-manager` and u2f PAM.
[ssh.nix](../../flake/modules/general-config/system/ssh/ssh.nix) lists the
authorized keys. `ssh.nix` sets `authorizedKeysInHomedir = false` and
`AuthenticationMethods publickey`, so a key that is not in that list cannot
log in, and `~/.ssh/authorized_keys` is ignored.

## Contents

- [Quick facts](#quick-facts)
- [0. Before either route](#0-before-either-route)
- [1. FIDO2 resident key (default)](#1-fido2-resident-key-default)
- [2. PIV key](#2-piv-key)
- [3. Authorize the key on the fleet](#3-authorize-the-key-on-the-fleet)
- [4. Test the login](#4-test-the-login)
- [5. Add a backup key or replace a lost one](#5-add-a-backup-key-or-replace-a-lost-one)
- [Troubleshooting](#troubleshooting)
- [See also](#see-also)

## Quick facts

- Default to the FIDO2 route. Use PIV only for a server whose OpenSSH is
  older than 8.2, or when no handle file may exist anywhere.
- The YubiKey applets are independent. Neither route touches the u2f
  registration `pam_u2f` uses, the OATH codes or the OTP slots.
- A key only works once its public line is in `ssh.nix` and the host has
  switched. Keep an existing session open until a test login succeeds.
- Never run `ykman fido reset` (deletes every FIDO2 credential, including the
  SSH key and the u2f registration) or `ykman piv reset` (deletes everything in
  PIV). Neither is part of this runsheet.
- FIDO2 PIN locks after 8 wrong tries in a row. PIV PIN blocks after 3, and
  the PUK unblocks it.
- Status of this runsheet: the FIDO2 route was run on `nire-durandal`
  2026-11-08 up to and including adding the public key to `ssh.nix`. A login
  with the key had not been tested at that date. The PIV commands come from
  the `ykman` and OpenSSH documentation and have not been run in this repo.

## 0. Before either route

1. Plug in one YubiKey and check it is the one you mean:
   ```sh
   ykman info
   ```
   Read the firmware version. The FIDO2 route's `ed25519-sk` needs 5.2.3 or
   newer. Ed25519 in PIV needs 5.7 or newer.
2. Run these read-only checks to see what is already on the key:
   ```sh
   ykman fido credentials list
   ykman piv info
   ```
3. Pick the route. Do not run both for the same purpose.

## 1. FIDO2 resident key (default)

The key pair is created on the YubiKey. The file on disk is a handle to the
credential, not a private key. With `-O resident` the YubiKey also stores the
credential, so the handle file can be recreated.

1. Set the FIDO2 PIN once per YubiKey. Skip if one is set.
   ```sh
   ykman fido access change-pin
   ```
2. Generate the key. Touch the key when it blinks and enter the PIN when asked.
   ```sh
   ssh-keygen -t ed25519-sk -O resident -O verify-required -C "yubikey"
   ```
   - `verify-required` makes every use need the PIN as well as a touch.
   - Use `-t ecdsa-sk` if a server's OpenSSH does not support `ed25519-sk`.
   - Use a distinct `-C` comment for each YubiKey, for example `yubikey-a`.
   - Enter the PIN carefully; each wrong try counts toward the lockout.
3. Take the public line from `<file>.pub` and fingerprint it:
   ```sh
   ssh-keygen -lf ~/.ssh/id_ed25519_sk.pub
   ```
4. Optional: keep no handle file. At the file prompt in step 2 give a path
   under `/run/user/$UID/`, copy the `.pub` somewhere, then delete both files.
   Load the key from the YubiKey when needed:
   ```sh
   ssh-add -K
   ```
5. Authorize the key (section 3).

Recover the handle file on another machine with `ssh-keygen -K`, which writes
`id_ed25519_sk_rk*` into the current directory.

## 2. PIV key

PIV is the smartcard applet. SSH reaches the key through a PKCS#11 library.
No handle file exists. It has its own PIN, PUK and management key, separate
from the FIDO2 PIN.

1. Read `ykman piv info` (section 0) and choose a free slot. `9a` is the usual
   one. Generating into an occupied slot overwrites it.
2. Replace the factory credentials:
   ```sh
   ykman piv access change-pin
   ykman piv access change-puk
   ykman piv access change-management-key --generate --protect
   ```
3. Generate the key in the slot. The PIN and touch policies are fixed at
   generation time and cannot be changed afterward.
   ```sh
   ykman piv keys generate --algorithm ECCP256 \
       --pin-policy ONCE --touch-policy ALWAYS 9a "$XDG_RUNTIME_DIR/yk-piv.pem"
   ```
4. Attach a self-signed certificate. Some PKCS#11 libraries only list a key
   that has one.
   ```sh
   ykman piv certificates generate --subject "ssh" 9a "$XDG_RUNTIME_DIR/yk-piv.pem"
   ```
5. Add `opensc` (library `opensc-pkcs11.so`) or `yubico-piv-tool` (library
   `libykcs11.so`) to the system packages, switch, and find the library path.
   `pcscd` is already enabled.
6. Print the SSH public line:
   ```sh
   ssh-keygen -D /path/to/opensc-pkcs11.so -e
   ```
7. Use the key with either of:
   ```sh
   ssh-add -s /path/to/opensc-pkcs11.so
   ```
   or `PKCS11Provider /path/to/opensc-pkcs11.so` in the ssh config.
   `ssh-agent` loads PKCS#11 libraries only from an allowlist set with `-P`;
   a `/nix/store` path is not on the default one.
8. Authorize the key (section 3).

The private key exists only on the YubiKey. A lost YubiKey means a lost key,
so authorize a second key (section 5) before relying on this one.

## 3. Authorize the key on the fleet

1. Do the work in a worktree (skill `use-a-worktree`).
2. Add the public line to `users.users.elly.openssh.authorizedKeys.keys` in
   [ssh.nix](../../flake/modules/general-config/system/ssh/ssh.nix), with a
   comment giving the date, the fingerprint and how to load the key.
3. Run `git add` on the file, then evaluate a host:
   ```sh
   nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath
   ```
4. Land it with skill `ship`, then `just switch` on each host that should
   accept the key.

## 4. Test the login

Keep one existing ssh session open while testing.

```sh
ssh-add -L                 # the key is listed (FIDO2: after ssh-add -K)
ssh -v ts-<host> true      # touch the key; the log shows "Server accepts key"
```

Use the `ts-<x>` name, not `nire-<x>`
([fleet/hosts.md](../fleet/hosts.md)). If the server refuses the key, check
that the host has switched and that the line in `ssh.nix` matches the
`.pub` file exactly.

## 5. Add a backup key or replace a lost one

- Backup: repeat this runsheet with a second YubiKey and a distinct comment,
  and add its line beside the first.
- Lost or retired key: delete its line from `ssh.nix`, ship it, switch every
  host, and record the removal in the file's history section. For a YubiKey you
  still hold, remove the credential with
  `ykman fido credentials delete` (FIDO2) or `ykman piv keys delete <slot>`
  (PIV).

## Troubleshooting

- `PIN incorrect`: stop and confirm the PIN. Each failure counts toward the
  lockout.
- `ssh-keygen` reports no device or `ssh-add -K` finds nothing: check
  `ykman list`, that the udev package is in place
  ([yubikey.nix](../../flake/modules/general-config/system/security/yubikey.nix)),
  and replug the key.
- PIN prompt never appears from the agent: the agent needs an askpass program
  (`SSH_ASKPASS`).
- PKCS#11 library lists no key: confirm the certificate step ran and that
  `pcscd` is running (`systemctl status pcscd`).
- Server rejects an `-sk` key: its OpenSSH is older than 8.2. Use the PIV
  route.

## See also

- [yubikey.nix](../../flake/modules/general-config/system/security/yubikey.nix):
  the services, udev rules and u2f PAM this runsheet relies on.
- [ssh.nix](../../flake/modules/general-config/system/ssh/ssh.nix): the
  authorized-key list and sshd policy.
- [fleet/hosts.md](../fleet/hosts.md): hosts and the `ts-<x>` naming rule.
- [upkeep-and-admin/maintenance-schedule.md](../upkeep-and-admin/maintenance-schedule.md):
  key expiry and rotation dates.
