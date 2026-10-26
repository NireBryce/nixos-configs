#!/usr/bin/env python3
"""The two JSON-reading steps of deployed-baseline.sh.

    deployed_baseline.py kernel-params <boot.json>
    deployed_baseline.py users <users-groups.json>

Prints no secrets: for each account `users` reports *where* the password
comes from, never the hash.
"""
import json
import sys


def kernel_params(boot_json):
    """The kernel command line from a bootspec boot.json, space-joined."""
    return " ".join(boot_json["org.nixos.bootspec.v1"].get("kernelParams", []))


def users_report(d):
    """Lines describing mutableUsers and each login-capable account."""
    out = [f"mutableUsers: {d.get('mutableUsers')}", ""]
    # Select on having a password source, plus root -- not on isNormalUser,
    # which users-groups.json does not carry. Filtering on it silently
    # omitted the only account you can actually log into.
    for user in d["users"]:
        has_pw = user.get("hashedPasswordFile") or user.get("hashedPassword")
        if not (has_pw or user["name"] == "root"):
            continue
        # where the password comes from, never what it is
        if user.get("hashedPasswordFile"):
            src = f"file {user['hashedPasswordFile']}"
        elif user.get("hashedPassword"):
            src = "hashedPassword set in the config"
        elif not d.get("mutableUsers"):
            # update-users-groups.pl writes "!" to /etc/shadow for a user with
            # no password source when mutableUsers is false: login by password
            # is locked, not passwordless.
            src = "none configured -> locked ('!'), mutableUsers=false"
        else:
            # mutableUsers=true keeps whatever /etc/shadow already holds, which
            # this config can't see -- check `sudo passwd -S <user>`.
            src = "WARNING: none configured, mutableUsers=true keeps the existing /etc/shadow entry -- check `sudo passwd -S`"
        out.append(f"  {user['name']:<10} uid={user.get('uid')}  password: {src}")
    return out


def main(argv):
    if len(argv) == 3 and argv[1] == "kernel-params":
        with open(argv[2]) as f:
            print(kernel_params(json.load(f)))
        return 0
    if len(argv) == 3 and argv[1] == "users":
        with open(argv[2]) as f:
            print("\n".join(users_report(json.load(f))))
        return 0
    print("usage: deployed_baseline.py kernel-params <boot.json> | users <users-groups.json>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
