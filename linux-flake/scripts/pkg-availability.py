#!/usr/bin/env python3
"""Can this package build on this system, and is Homebrew already installing it?

Exists because the alternative is guessing, and guessing is what happened. Every
Linux-only guard in nirePackages/ is a claim about platform support, but
`lib.mkIf (!pkgs.stdenv.isDarwin)` gets reached for whenever a shared module
looks Linux-shaped -- which is a different question from whether the pinned
nixpkgs can build it on aarch64-darwin. Checking by hand meant writing the same
expression out again each time, so mostly nobody did.

    pkg-availability.py obsidian discord kitty
    pkg-availability.py --all
    pkg-availability.py --system x86_64-linux vlc gimp

Columns:

  VERDICT   available    lib.meta.availableOn says yes: meta.platforms includes
                         this system and meta.badPlatforms does not.
            unsupported  exists, but not for this system. A guard is
                         load-bearing here -- without one the host does not
                         evaluate at all.
            missing      no such attribute in the pinned nixpkgs.
            eval-error   evaluating the attribute threw. Reported rather than
                         swallowed: "it threw" is itself the answer when the
                         question is whether a host can import the module.

  BROKEN    meta.broken. availableOn does NOT consider it -- nixpkgs
            lib/meta.nix checks platforms and badPlatforms only -- so a package
            can read `available` and still refuse to build without allowBroken.

  CASK      a cask in nire/macos/homebrew/homebrew.nix whose name looks like
            this package's. Fuzzy, and a hint rather than a fact: the names do
            not match 1:1 (google-chrome/chrome, zoom-us/zoom,
            bitwarden-desktop/bitwarden). A hit means "check whether darwin is
            getting two copies", not "it is".

`available` PLUS a cask hit is the interesting case, and the one no
platform-shaped guard would ever catch: the package builds fine, the machine
just does not need the nix copy. That is how nire-lysithea came to fetch
Obsidian's .dmg from GitHub on every build -- unfree, so never in
cache.nixos.org, so a 503 upstream on 2026-08-12 failed the whole build for an
app Homebrew had already installed.

Availability is judged against the flake's PINNED nixpkgs, through getFlake and
not the registry: the answer only means anything for the nixpkgs the hosts
actually evaluate with. allowUnfree is set on the probe instance for the same
reason it is set system-side -- without it, `obsidian` and `discord` throw
before any of this can reach their meta.
"""
import argparse, json, pathlib, re, subprocess, sys, tempfile

HERE     = pathlib.Path(__file__).resolve().parent
FLAKE    = HERE.parent
HOMEBREW = FLAKE / 'modules/nire/macos/homebrew/homebrew.nix'

# `home.packages = with pkgs; [ a b c ]`, possibly spanning lines. Used only by
# --all, and only a convenience: this finds the ~70 files using the bare
# single-package wrapper shape and misses everything installed through a
# `programs.*.enable`, which is most of shell-config/. Name a package
# explicitly when you actually care about the answer.
PKGLIST = re.compile(r'home\.packages\s*=\s*with pkgs;\s*\[(.*?)\]', re.S)
PKGNAME = re.compile(r'^[a-zA-Z][a-zA-Z0-9._-]*$')
COMMENT = re.compile(r'#[^\n]*')
CASKS   = re.compile(r'casks\s*=\s*\[(.*?)\];', re.S)

# Suffixes nixpkgs adds to tell a desktop app apart from its library or CLI.
# Stripped before matching against cask names, which never carry them.
SUFFIXES = ('-desktop', '-us', '-bin', '-unwrapped', '-wayland')

PROBE = '''
let
    flake  = builtins.getFlake "%(flake)s";
    lib    = flake.inputs.nixpkgs.lib;

    # allowBroken so a broken package still resolves far enough to be REPORTED
    # as broken, instead of throwing and landing in eval-error, which says less.
    pkgs   = import flake.inputs.nixpkgs {
        system = "%(system)s";
        config = { allowUnfree = true; allowBroken = true; };
    };

    names  = builtins.fromJSON (builtins.readFile %(names)s);

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
'''


def strip_comments(text):
    """Nix comments only. Good enough here: no `#` appears inside the string
    literals in these files, and the alternative is a Nix parser."""
    return COMMENT.sub('', text)


def scan_packages():
    """Package names named in `home.packages` blocks across nirePackages/."""
    names = set()
    for p in sorted((FLAKE / 'modules/nirePackages').rglob('*.nix')):
        if any(part.startswith('_') for part in p.parts):
            continue                       # import-tree ignores these; so do we
        for block in PKGLIST.findall(strip_comments(p.read_text())):
            names.update(t for t in block.split() if PKGNAME.match(t))
    return names


def casks():
    block = CASKS.search(strip_comments(HOMEBREW.read_text()))
    return set(re.findall(r'"([a-z0-9@.-]+)"', block.group(1))) if block else set()


def cask_for(pkg, known):
    stem = pkg.split('.')[-1]
    for suffix in SUFFIXES:
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    for c in sorted(known):
        if c == stem or stem in c or c in stem:
            return c
    return ''


def probe(names, system):
    with tempfile.NamedTemporaryFile('w', suffix='.json') as f:
        json.dump(sorted(names), f)
        f.flush()
        expr = PROBE % {'flake': FLAKE, 'system': system,
                        'names': json.dumps(f.name)}
        out = subprocess.run(['nix', 'eval', '--impure', '--raw', '--expr', expr],
                             capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(out.stderr.strip() or 'nix eval failed')
    return json.loads(out.stdout)


ORDER = {'available': 0, 'unsupported': 1, 'eval-error': 2, 'missing': 3}


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*', help='package attribute paths')
    ap.add_argument('--system', default='aarch64-darwin')
    ap.add_argument('--all', action='store_true',
                    help='derive the list from home.packages across nirePackages/')
    args = ap.parse_args()

    names = set(args.names) | (scan_packages() if args.all else set())
    if not names:
        ap.error('name at least one package, or pass --all')

    rows  = probe(names, args.system)
    known = casks()
    w     = max([len(r['name']) for r in rows] + [7])

    print(f'{args.system}\n')
    print(f'{"PACKAGE":<{w}}  {"VERDICT":<11}  {"BROKEN":<6}  CASK')
    for r in sorted(rows, key=lambda r: (ORDER.get(r['verdict'], 9), r['name'])):
        print(f'{r["name"]:<{w}}  {r["verdict"]:<11}  '
              f'{"yes" if r["broken"] else "":<6}  {cask_for(r["name"], known)}')


if __name__ == '__main__':
    main()
