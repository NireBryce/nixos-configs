#!/usr/bin/env bash
# Is this package actually buildable on this system, and is Homebrew already
# installing it anyway?
#
# Exists because the alternative is guessing. Every Linux-only guard in
# nirePackages/ is a claim about a package's platform support, and until this
# script those claims were made by eye -- `lib.mkIf (!pkgs.stdenv.isDarwin)`
# gets reached for whenever a shared module looks Linux-shaped, which is not
# the same question as whether nixpkgs can build it on aarch64-darwin. Several
# of the existing guards were put in without anyone checking, because checking
# by hand meant writing this expression out again each time.
#
#     scripts/pkg-availability.sh obsidian discord kitty
#     scripts/pkg-availability.sh --all
#     scripts/pkg-availability.sh --system x86_64-linux vlc gimp
#
# Columns:
#
#   VERDICT   available   lib.meta.availableOn says yes -- meta.platforms
#                         includes this system and meta.badPlatforms does not.
#             unsupported the package exists but not for this system. A guard
#                         here is load-bearing: without it the host does not
#                         evaluate.
#             missing     no such attribute in the pinned nixpkgs at all.
#             eval-error  evaluating the attribute threw. Shown rather than
#                         swallowed, because "it threw" is itself the answer
#                         when deciding whether a host can import the module.
#   BROKEN    meta.broken. availableOn does NOT consider this (nixpkgs
#             lib/meta.nix checks platforms/badPlatforms only), so a package
#             can be "available" and still refuse to build without
#             allowBroken. Worth seeing next to the verdict rather than
#             discovering during a switch.
#   CASK      a cask in nire/macos/homebrew/homebrew.nix whose name looks like
#             this package's. Fuzzy, and deliberately labelled as a hint: the
#             names do not match 1:1 (google-chrome/chrome, zoom-us/zoom,
#             bitwarden-desktop/bitwarden). A hit means "check whether darwin
#             is getting two copies", not "it is".
#
# `available` plus a cask hit is the interesting case, and the one no
# platform-shaped guard would ever have caught: the package builds fine, the
# machine just does not need the nix copy. That is how nire-lysithea came to
# fetch Obsidian's .dmg from GitHub on every build -- unfree, so never cached,
# so a 503 upstream on 2026-08-12 failed the whole build for an app Homebrew
# had already installed.
#
# Availability is judged against the flake's PINNED nixpkgs, via getFlake, not
# against the registry -- the answer is only meaningful for the nixpkgs the
# hosts actually evaluate with. allowUnfree is set on the probe instance for
# the same reason it is set system-side: without it, evaluating `obsidian` or
# `discord` throws before any of this can look at meta.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
flake=$(cd "$here/.." && pwd)
homebrew="$flake/modules/nire/macos/homebrew/homebrew.nix"

system="aarch64-darwin"
all=0
names=()

while [ $# -gt 0 ]; do
    case "$1" in
        --system) system="$2"; shift 2 ;;
        --all)    all=1; shift ;;
        -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
        -*)       echo "unknown flag: $1" >&2; exit 2 ;;
        *)        names+=("$1"); shift ;;
    esac
done

# --all derives the list by grepping `home.packages` blocks out of the module
# tree. Regex over nix source, so it is a convenience and not authoritative:
# it finds the ~70 files using the bare `home.packages = with pkgs; [ ... ]`
# shape and misses anything installed through a `programs.*.enable`, which is
# most of shell-config/. Name a package explicitly when you care about it.
if [ "$all" = 1 ]; then
    while IFS= read -r n; do names+=("$n"); done < <(
        find "$flake/modules/nirePackages" -name '*.nix' -not -path '*/_*' -print0 |
        xargs -0 awk '
            /home\.packages *= *with pkgs; *\[/ { inlist = 1; sub(/.*\[/, ""); }
            inlist {
                line = $0
                sub(/\].*/, "", line)
                n = split(line, toks, /[ \t]+/)
                for (i = 1; i <= n; i++)
                    if (toks[i] ~ /^[a-zA-Z][a-zA-Z0-9._-]*$/) print toks[i]
                if ($0 ~ /\]/) inlist = 0
            }
        ' | sort -u
    )
fi

if [ ${#names[@]} -eq 0 ]; then
    echo "usage: $(basename "$0") [--system SYS] [--all] [pkg ...]" >&2
    exit 2
fi

# The cask list, for the CASK column. Only the `casks = [ ... ]` block --
# `brews` are CLI tools and are a different conversation from a GUI app being
# installed twice.
casks=$(sed -n '/casks *= *\[/,/\];/p' "$homebrew" | grep -oE '"[a-z0-9@.-]+"' | tr -d '"' | sort -u || true)

# Handed to nix through a file rather than interpolated into the --expr string.
# The list is user input, and nesting shell quoting inside a nix string literal
# inside a bash string was the kind of thing that works until a package name
# has a dot in it.
names_json=$(mktemp)
trap 'rm -f "$names_json"' EXIT
printf '%s\n' "${names[@]}" | sort -u | python3 -c '
import json, sys
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))
' > "$names_json"

report=$(nix eval --impure --raw --expr '
let
    flake  = builtins.getFlake "'"$flake"'";
    lib    = flake.inputs.nixpkgs.lib;

    # allowBroken so that a broken package still resolves far enough to be
    # REPORTED as broken, rather than throwing and landing in eval-error where
    # it says much less.
    pkgs   = import flake.inputs.nixpkgs {
        system = "'"$system"'";
        config = { allowUnfree = true; allowBroken = true; };
    };

    names  = builtins.fromJSON (builtins.readFile "'"$names_json"'");

    probe = n:
        let
            r = builtins.tryEval (
                let p = lib.attrByPath (lib.splitString "." n) null pkgs; in
                if p == null then { verdict = "missing"; broken = false; }
                else {
                    verdict =
                        if lib.meta.availableOn pkgs.stdenv.hostPlatform p
                        then "available" else "unsupported";
                    broken  = p.meta.broken or false;
                });
        in { name = n; } // (if r.success then r.value
                            else { verdict = "eval-error"; broken = false; });
in
    builtins.toJSON (map probe names)
' 2>&1) || { echo "$report" >&2; exit 1; }

printf '%s\n' "$report" | CASKS="$casks" SYSTEM="$system" python3 -c '
import json, sys, os

rows  = json.load(sys.stdin)
casks = set(filter(None, os.environ["CASKS"].split("\n")))

def cask_for(pkg):
    # Deliberately loose: strip the suffixes nixpkgs adds to disambiguate a
    # desktop app from its library or CLI, then accept containment either way.
    stem = pkg.split(".")[-1]
    for suffix in ("-desktop", "-us", "-bin", "-unwrapped", "-wayland"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
    for c in sorted(casks):
        if c == stem or stem in c or c in stem:
            return c
    return ""

w = max([len(r["name"]) for r in rows] + [7])
print(f"{os.environ[chr(83)+chr(89)+chr(83)] if False else os.environ['SYSTEM']}\n")
print(f"{'PACKAGE':<{w}}  {'VERDICT':<11}  {'BROKEN':<6}  CASK")
order = {"available": 0, "unsupported": 1, "eval-error": 2, "missing": 3}
for r in sorted(rows, key=lambda r: (order.get(r["verdict"], 9), r["name"])):
    print(f"{r['name']:<{w}}  {r['verdict']:<11}  "
          f"{('yes' if r['broken'] else ''):<6}  {cask_for(r['name'])}")
' CASKS="$casks" SYSTEM="$system"
