# Every nix command hangs after a switch

_Last modified: 2026-11-15_

After a `switch` that restarts `nix-daemon.service`, every nix command can hang
with no output, and `home-manager-<user>.service` fails with `start operation
timed out`. The cause is old-generation `nix-daemon` workers that outlived the
restart and still hold the store lock. This page gives the symptoms, the
check, and the fix. Observed on `nire-durandal`, 2026-11-15.

## Contents

- [Quick facts](#quick-facts)
- [Diagnosis](#diagnosis)
- [Fix](#fix)
- [Prevention](#prevention)
- [See also](#see-also)

## Quick facts

- **Symptom:** `just switch` ends with `Failed to restart home-manager-elly.service`
  and `warning: the following units failed: home-manager-elly.service`. The
  journal for that unit shows `Starting Home Manager activation`, a 5 minute
  gap, then `error: interrupted by the user`.
- **Cause:** the new `nix-daemon` logs `waiting for exclusive access to the Nix
  store...` for each connection and never gets it. Workers left from the old
  daemon hold the shared lock.
- **Test:** `timeout 60 nix-build --quiet --expr '{}' --no-out-link`. It returns
  in well under a second when healthy and times out when the lock is held. This
  is the first command Home Manager's activation script runs, so it is the
  cause of the unit timeout.
- **Fix:** kill the orphaned old workers (below), then `sudo systemctl restart
  home-manager-<user>.service`.
- **Nothing is broken in the config.** The generation had already activated;
  only the Home Manager step was blocked.

## Diagnosis

1. Read the unit log: `journalctl -u home-manager-elly.service -b`. A hang right
   after `Starting Home Manager activation` points at the sanity check, which
   is a `nix-build` call (see the Home Manager `activate` script).
2. Confirm nix itself hangs: `timeout 60 nix-build --quiet --expr '{}'
   --no-out-link`, or `timeout 20 nix store info --store daemon`.
3. Read the daemon log: `journalctl -u nix-daemon -b --since <switch time>`.
   Repeated `waiting for exclusive access to the Nix store...` lines confirm
   the lock.
4. Find the holders:

   ```sh
   ps -eo pid,ppid,etime,cmd | grep '[n]ix-daemon'
   ```

   The main daemon is `nix-daemon --daemon`. Its workers have it as their
   parent. The stale ones have **parent PID 1** and an elapsed time older
   than the restart. On 2026-11-15 these were five workers (`nix-daemon
   <pid>`) from before the switch, started by the editor's `nixd` language
   server and its `nixd-attrset-eval` helpers.

## Fix

Kill the workers whose parent is PID 1 and which predate the restart:

```sh
kill <pid> <pid> ...        # SIGTERM first; -9 if they ignore it
timeout 60 nix-build --quiet --expr '{}' --no-out-link   # returns at once
sudo systemctl restart home-manager-elly.service
```

Nix commands queued behind the lock (other terminals, `nix run`, `nix
develop`) continue on their own once it clears. The language server that owned
the workers is a separate process: restart it from the editor, or it
reconnects on the next request.

An agent session may not be allowed to kill these (the permission check
denied it on 2026-11-15). Give the user the `kill` line to run.

## Prevention

Nothing in the config prevents it. Before a `switch` on a host with an editor
open on this repo, stopping the language server first avoids the orphans.
After a switch, if `just switch` reports a failed Home Manager unit, run the
test above before anything else.

## See also

- [name-resolution](name-resolution.md) and [tailnet](tailnet.md) cover the
  other fleet-wide "works from one place, hangs from another" failures.
