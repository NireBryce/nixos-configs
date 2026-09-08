{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # `sops.age.sshKeyPaths` (sops.nix) is enough for NixOS's OWN
        # activation-time secret decryption -- that already works, proven by
        # /run/secrets existing on every host that imports this category.
        # This module fixes a SEPARATE, narrower problem: a human running
        # `sops secrets.yaml` interactively, as root, to view or edit it.
        #
        # Found 2026-08-29 on nire-cube: `sudo env
        # SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key sops
        # secrets.yaml` failed against EVERY recipient with "identity did
        # not match" -- including cube's own enrolled key -- despite the
        # identity that key derives to being verified THREE separate ways
        # (ssh-to-age on the .pub file, a live ssh-keyscan against cube's
        # actual running sshd, and ssh-to-age run directly against the
        # private key file) to be byte-identical to the enrolled recipient.
        # secrets.yaml's per-recipient blocks are also provably correct --
        # every `sops <file>` save re-wraps the data key for every current
        # recipient using nothing but that recipient's PUBLIC key, so there
        # is no code path in a normal save that could desync a label from
        # its own ciphertext.
        #
        # This is a KNOWN, currently-unresolved upstream limitation, not a
        # mystery specific to this repo: getsops/sops's own SSH-key-to-age
        # conversion (the code path SOPS_AGE_SSH_PRIVATE_KEY_FILE uses)
        # produces a DIFFERENT age identity than the standalone `ssh-to-age`
        # tool does for the same SSH key -- reported at
        # https://github.com/Mic92/sops-nix/issues/824, open since, no
        # maintainer response, no milestone. That's exactly the gap this
        # repo falls into: `.sops.yaml` is enrolled entirely via
        # `host-age-key.sh` (ssh-to-age), so sops's OWN conversion was never
        # going to agree with it. `sops-install-secrets` (sops-nix's
        # activation-time decrypt binary -- proven working by /run/secrets
        # existing) evidently uses a conversion that DOES agree with
        # ssh-to-age, so the bug is specifically scoped to the plain `sops`
        # CLI's interactive SSH-key support, confirmed here: converting the
        # SAME key with ssh-to-age to a native age identity file and
        # pointing `SOPS_AGE_KEY_FILE` at it instead decrypted cleanly, no
        # code change, same key. Don't expect this workaround to become
        # removable soon -- re-check the upstream issue before assuming a
        # sops version bump fixed it.
        #
        # Don't rely on a hand-run conversion to fix this: durandal and
        # tenacity wipe the `/root` btrfs subvolume in initrd on EVERY boot
        # (WARN-impermanence.nix), so anything hand-created under /root
        # vanishes at the next reboot with no memory of ever having been
        # needed -- exactly the shape of bug impermanence quietly hides
        # instead of preventing. This has to regenerate itself every boot to
        # actually be fixed there, hence a systemd oneshot rather than a
        # runbook step.
        #
        # Regenerating UNCONDITIONALLY on every boot (contrast
        # grafana-secret-key-setup.service, which creates its secret only
        # if missing) is correct here, not reckless: this is a pure,
        # deterministic derivation of a key that already exists elsewhere on
        # the host, not a value anything else depends on staying stable --
        # if the host's SSH key is ever rotated, this should track it
        # automatically rather than going stale the way `.sops.yaml`'s own
        # entries have (see impermanence-and-secrets.md's Secrets section).
        #
        # NOT mirroring sops-darwin.nix's `environment.variables
        # SOPS_AGE_KEY_FILE` here on purpose: that variable is exported
        # system-wide, to every user's shell -- fine on darwin, where it
        # points at elly's own home directory. Here it would have to point
        # at a ROOT-owned path, and setting that globally would hand elly's
        # own (unprivileged, unrelated) `sops` invocations a path they can't
        # read instead of leaving them alone. No env var needed anyway:
        # sops's default identity-file lookup already resolves per-$HOME on
        # Linux, so `sudo`'s HOME=/root finds this file with zero
        # configuration -- confirmed directly (`sudo sops secrets.yaml`,
        # no env vars, succeeded once this file existed).
        #
        # `environment.variables.EDITOR`/`VISUAL` below IS exported
        # system-wide, unlike SOPS_AGE_KEY_FILE above -- and that's fine
        # here, unlike there: SOPS_AGE_KEY_FILE would have to point at a
        # ROOT-owned path, wrong for elly's own unprivileged `sops` calls,
        # but "micro" is the same correct value for every user on this
        # config (elly's own copy comes from shell-env.nix's
        # `home.sessionVariables`, a Home Manager option that only lands in
        # HER shell -- root has no Home Manager profile at all, so without
        # this, `sudo sops secrets.yaml` falls through to sops's built-in
        # default, vi, silently inconsistent with elly's configured editor).
        # Filed as issue #118, found while checking cube's interactive sops
        # flow end to end.
        #
        # NIX STORE SAFETY, read before touching this file: the `script`
        # below is pure shell text -- literal commands and file PATHS, no
        # key material -- so only that inert logic ever lands in the store.
        # The actual private key bytes are read from /etc/ssh/... and
        # written to /root/.config/... entirely at runtime, as root, on the
        # live host; Nix's build/eval machinery never touches them. Do NOT
        # "simplify" this with `builtins.readFile` on the host key or any
        # other evaluation-time read of it -- that would bake the actual
        # private key into a world-readable, content-addressed store path,
        # liable to be copied out by a substituter push, `nix copy`, or any
        # binary cache -- a categorically worse exposure than "root-only on
        # this one machine," which is all this module is meant to stay.
        flake.modules.nixos.${moduleName} = { config, lib, pkgs, ... }: {
            # Root has no Home Manager profile, so elly's `EDITOR = "micro"`
            # (shell-env.nix) never reaches it -- see the header comment.
            # Same value, exported system-wide instead of per-user.
            environment.variables = {
                EDITOR = "micro";
                VISUAL = "micro";
            };

            # mkIf on the VALUE, not a config-conditioned module shape --
            # the latter is exactly the "config referenced in imports"
            # infinite-recursion trap NixOS's own module system warns about
            # (hit and fixed here 2026-08-29): the option always exists,
            # its value collapses to nothing when there's no ed25519 host
            # key to convert.
            # No ed25519 host key -> sshKeyPaths is [] -> mkIf false -> this
            # whole service is never created, and `lib.head` below never
            # gets forced (mkIf's laziness, not a try/catch) -- so a
            # host missing one doesn't crash eval, it just gets no fix.
            # That mirrors sops.nix itself: NixOS's own activation-time
            # decrypt already depends on the same list being non-empty, so
            # this isn't a new fragility.
            #
            # `lib.head`, not a fold over the whole list: every real host
            # here (durandal/tenacity/cube) generates exactly one ed25519
            # host key, the NixOS default, same assumption sops.nix's own
            # sshKeyPaths usage already makes. If a host ever legitimately
            # had more than one, only the first would get converted here --
            # a real limitation, not a crash, and not a case this repo has
            # today.
            systemd.services.sops-interactive-age-key = lib.mkIf (config.sops.age.sshKeyPaths != [ ]) {
                description = "Convert this host's SSH host key to a native age identity, for interactive `sops`";
                wantedBy    = [ "multi-user.target" ];

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                };

                script = ''
                    set -euo pipefail
                    mkdir -p /root/.config/sops/age
                    umask 077
                    ${pkgs.ssh-to-age}/bin/ssh-to-age -private-key \
                        -i ${lib.head config.sops.age.sshKeyPaths} \
                        > /root/.config/sops/age/keys.txt.tmp
                    mv -f /root/.config/sops/age/keys.txt.tmp \
                        /root/.config/sops/age/keys.txt
                    chown root:root /root/.config/sops/age/keys.txt
                    chmod 600 /root/.config/sops/age/keys.txt
                '';
            };
        };
}
