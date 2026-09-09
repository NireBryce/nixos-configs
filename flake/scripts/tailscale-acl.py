#!/usr/bin/env python3
"""Read/write the tailnet policy file (ACLs, `svc:` service definitions,
autoApprovers) through Tailscale's REST API, instead of the admin console's
HuJSON editor.

Why this exists: wiki/open-threads.md's Tailscale Services entry deferred
`svc:` partly because the policy file's state lives outside this repo, in
Tailscale's control plane, editable only by hand in the console. The API
(`GET`/`POST /api/v2/tailnet/{tailnet}/policy`) makes it scriptable instead
-- this is that script. It never makes the ACL the source of truth on its
own: the intended flow is edit a local HuJSON file in this repo, review the
diff, then `apply` it, so history lives in `git log` same as everything
else here.

    tailscale-acl.py get [--out FILE]      Fetch the live policy file (HuJSON)
    tailscale-acl.py diff FILE             Show live vs FILE, no changes made
    tailscale-acl.py apply FILE            POST FILE as the new policy, after
                                            confirming the diff isn't empty

The `svc:` service objects themselves (name/tags/ports) are a SEPARATE
resource from the policy file above -- confirmed against
tailscale/tailscale's own client source (PR #14539) after the policy
endpoint rejected a top-level "services" key with `unknown field
"services"`: that key belongs to the per-node *serve* config
(nixpkgs' services.tailscale.serve), not the tailnet policy.

    tailscale-acl.py vip-get NAME           GET vip-services/by-name/NAME
    tailscale-acl.py vip-put NAME FILE      PUT FILE (JSON: name/tags/ports/
                                             comment) as that service, after
                                             confirming
    tailscale-acl.py vip-delete NAME        DELETE that service, after
                                             confirming

The API token is never taken as an argument or env var by this script --
that would put it in `ps aux`/shell history. It's read once, narrowly, out
of this repo's sops secret:

    sops -d --extract '["tailscale_api_token"]' <secrets.yaml>

per skill secrets-hygiene: a bare `sops -d` prints the whole file, this
extracts one key. TAILNET defaults to the tailnet this repo's hosts are
already on (see wiki/categories/reverse-proxy.md) but can be overridden
with $TAILSCALE_TAILNET for a different one.
"""
import os, subprocess, sys, urllib.request, urllib.error, difflib, pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
SECRETS_FILE = REPO_ROOT / "flake/modules/nire/system/secrets/secrets.yaml"
TAILNET = os.environ.get("TAILSCALE_TAILNET", "moose-micro.ts.net")
BASE = f"https://api.tailscale.com/api/v2/tailnet/{TAILNET}"
ACL_API = f"{BASE}/acl"
def vip_api(name):
    # NOT /vip-services/by-name/{name} -- that 404s with a bare "404 page
    # not found" (a routing miss). This path returns a real JSON 404
    # ("service not found") for a name that doesn't exist yet, confirming
    # it's the right route. tailscale/tailscale PR #14539's client source
    # names the Go method GetVIPServiceByName but the URL it builds is
    # this shorter form -- the method name outlived a path that changed.
    return f"{BASE}/vip-services/{name}"


def get_token():
    out = subprocess.run(
        ["sops", "-d", "--extract", '["tailscale_api_token"]', str(SECRETS_FILE)],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        sys.exit(
            "Could not read tailscale_api_token from secrets.yaml -- add it "
            "with `sops " + str(SECRETS_FILE) + "` first.\n" + out.stderr
        )
    return out.stdout.strip()


def request(url, method, body=None, content_type="application/hujson"):
    token = get_token()
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    data = None
    if body is not None:
        data = body.encode()
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, data=data) as resp:
            return resp.read().decode()
    except urllib.error.HTTPError as e:
        # Never echo headers -- the request carried the bearer token.
        sys.exit(f"Tailscale API error {e.code}: {e.read().decode()[:500]}")


def cmd_get(args):
    policy = request(ACL_API, "GET")
    if args and args[0] == "--out":
        pathlib.Path(args[1]).write_text(policy)
        print(f"wrote {args[1]}")
    else:
        print(policy)


def cmd_diff(args):
    if not args:
        sys.exit("usage: tailscale-acl.py diff FILE")
    live = request(ACL_API, "GET").splitlines(keepends=True)
    local = pathlib.Path(args[0]).read_text().splitlines(keepends=True)
    diff = list(difflib.unified_diff(live, local, fromfile="live", tofile=args[0]))
    print("".join(diff) if diff else "no difference")
    return bool(diff)


def cmd_apply(args):
    if not args:
        sys.exit("usage: tailscale-acl.py apply FILE")
    if not cmd_diff(args):
        print("nothing to apply")
        return
    reply = input(f"POST {args[0]} as the new tailnet policy? [y/N] ")
    if reply.lower() != "y":
        sys.exit("aborted")
    body = pathlib.Path(args[0]).read_text()
    print(request(ACL_API, "POST", body))


def cmd_vip_get(args):
    if not args:
        sys.exit("usage: tailscale-acl.py vip-get NAME")
    print(request(vip_api(args[0]), "GET"))


def cmd_vip_put(args):
    if len(args) < 2:
        sys.exit("usage: tailscale-acl.py vip-put NAME FILE")
    name, file = args[0], args[1]
    body = pathlib.Path(file).read_text()
    print(f"PUT {vip_api(name)}\n{body}")
    reply = input(f"Create/update service {name} as shown above? [y/N] ")
    if reply.lower() != "y":
        sys.exit("aborted")
    print(request(vip_api(name), "PUT", body, content_type="application/json"))


def cmd_vip_delete(args):
    if not args:
        sys.exit("usage: tailscale-acl.py vip-delete NAME")
    name = args[0]
    reply = input(f"DELETE service {name}? [y/N] ")
    if reply.lower() != "y":
        sys.exit("aborted")
    print(request(vip_api(name), "DELETE") or "deleted")


COMMANDS = {
    "get": cmd_get, "diff": cmd_diff, "apply": cmd_apply,
    "vip-get": cmd_vip_get, "vip-put": cmd_vip_put, "vip-delete": cmd_vip_delete,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    COMMANDS[sys.argv[1]](sys.argv[2:])
