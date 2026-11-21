# retire-old-ssh-sign: finishing the signing-wrapper switch

_Last modified: 2026-11-21_

Open until the cleanup has run on every clone that has it. Delete this file
then.

## What it is

Git signs commits through a store-path script, `git-ssh-sign`, set as
`gpg.ssh.program` in `flake/modules/users-config/elly/elly-git/elly-git.nix`.
It replaces a hand-made `~/.config/git/ssh-sign`, which a repo-local
`gpg.ssh.program` in `.git/config` wired in. Repo-local config overrides the
global setting, so until that entry is removed the old script stays in use and
the new one never runs in that clone.

`just retire-old-ssh-sign` removes the override and, with `--remove-script`,
the old script. It is a dry run unless given `--apply`. How it works and what
it leaves alone: `wiki/ssh/commit-signing.md`.

After a successful NixOS `just switch` or `just boot`, `rebuild.sh` prints a
one-time note to run it. The note appears only while the override or the old
script exists and the evaluated config carries the new wrapper, so it stops on
its own once the cleanup is done.

## State as of 2026-11-21

- Merged: the recipe, its script and tests, the wiki page, and the switch/boot
  note.
- Not merged: the wrapper itself (PR #658). Until it lands and a host switches
  to it, the note stays silent and the cleanup must not run: signing from a
  non-interactive shell would fall back to plain `ssh-keygen` and fail without
  `SSH_AUTH_SOCK`.
- The shared checkout at `/home/elly/nixos` still carries the override, and
  `~/.config/git/ssh-sign` still exists on `nire-durandal`.

## To do

1. Merge #658, then `just switch` on `nire-durandal`.
2. In the shared checkout, run `just retire-old-ssh-sign` (dry run), then
   `just retire-old-ssh-sign --apply --remove-script`.
3. Check each other clone and host for the same override. Not yet checked:
   `nire-tenacity`, and `/home/elly/projects/nixos/nixos-configs` (the repo
   that `elly-git.nix` lists for git maintenance). On each:

   ```sh
   git -C <clone> config --local --get gpg.ssh.program
   ls ~/.config/git/ssh-sign
   ```

4. After #658 lands, change the hint the wrapper prints. It ends "Signing
   policy: AGENTS.md, commit signing", but no AGENTS.md section has that title.
   Point it at `wiki/ssh/commit-signing.md`.
5. After #658 is switched, update the commit-signing paragraph in `AGENTS.md`
   (under "Working in this repo") and the "Commit signing" section of
   `wiki/config-structure/categories/elly.md`: `git commit` no longer needs an
   `SSH_AUTH_SOCK` prefix, and `elly.md` should link the new wiki page.
6. Delete this file.

## Related

- `wiki/ssh/commit-signing.md`: what the wrapper does, what its failure line
  means, and the cleanup recipe.
- `flake/scripts/retire-old-ssh-sign.sh` and its tests.
- `flake/scripts/rebuild.sh`, `ssh_sign_note`: the one-time note.
