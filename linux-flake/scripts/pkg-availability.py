#!/usr/bin/env python3
"""Can this package build on this system, and is Homebrew already installing it?

Exists because the alternative is guessing, and guessing is what happened. Every
Linux-only guard in nirePackages/ is a claim about platform support, but
`lib.mkIf (!pkgs.stdenv.isDarwin)` gets reached for whenever a shared module
looks Linux-shaped -- a different question from whether the pinned nixpkgs can
build it on aarch64-darwin. Checking by hand meant writing the same expression
out again each time, so mostly nobody did.

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

  CASK      a cask in nire/macos/homebrew/homebrew.nix installing the same
            thing, with the signal that identified it. See match_cask.

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

# Homebrew's own cache of the cask API -- every cask's token and homepage,
# offline. Read directly rather than shelling out to `brew info --json=v2`,
# which crashes on this cask list: Homebrew 5.1.6 raises "undefined method
# 'to_sym' for nil" out of cask_struct_generator.rb when one of the 59 is in
# the batch. The cache is plain JSON under a JWS envelope and has no such
# problem.
CASK_API = pathlib.Path.home() / 'Library/Caches/Homebrew/api/cask.jws.json'

# `home.packages = with pkgs; [ a b c ]`, possibly spanning lines. Used only by
# --all, and a convenience only: it finds the ~70 files using the bare
# single-package wrapper shape and misses everything installed through a
# `programs.*.enable`, which is most of shell-config/. Name a package
# explicitly when you actually care about the answer.
PKGLIST = re.compile(r'home\.packages\s*=\s*with pkgs;\s*\[(.*?)\]', re.S)
PKGNAME = re.compile(r'^[a-zA-Z][a-zA-Z0-9._-]*$')
# `programs.kitty = { ... }` / `services.espanso = { ... }`. The option name is
# used as the package name -- true for kitty and espanso, the two that matter
# here, and false often enough that --duplicates reports rather than acts.
PROGRAM = re.compile(r'\b(?:programs|services)\.([a-zA-Z][a-zA-Z0-9-]*)\s*=')
COMMENT = re.compile(r'#[^\n]*')
CASKS   = re.compile(r'casks\s*=\s*\[(.*?)\];', re.S)

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
                if p == null then { verdict = "missing"; broken = false; homepage = ""; }
                else {
                    verdict =
                        if lib.meta.availableOn pkgs.stdenv.hostPlatform p
                        then "available" else "unsupported";
                    broken   = p.meta.broken or false;
                    homepage = p.meta.homepage or "";
                });
        in { name = n; } // (if r.success then r.value
                            else { verdict = "eval-error"; broken = false; homepage = ""; });
in
    builtins.toJSON (map probe names)
'''


def strip_comments(text):
    """Nix comments only. Good enough here -- no `#` appears inside the string
    literals in these files -- and the alternative is a Nix parser."""
    return COMMENT.sub('', text)


def scan_packages():
    """package name -> {(module path relative to modules/, shape)}.

    Two shapes, because the fix differs between them and --duplicates has to say
    which one it found:

      packages  `home.packages = with pkgs; [ foo ]`. The module contributes a
                package and nothing else, so excluding it on darwin costs
                nothing.
      programs  `programs.foo` / `services.foo`. The option name is taken as the
                package name, which is right often enough to be worth reporting
                and is why this is a report and not an edit: these modules
                usually ALSO generate config the Homebrew copy will read. See
                --duplicates output.

    Regex over Nix source either way, so this finds things rather than proving
    them. Anything under a `_` directory is skipped, matching import-tree.
    """
    found = {}
    for p in sorted((FLAKE / 'modules/nirePackages').rglob('*.nix')):
        if any(part.startswith('_') for part in p.parts):
            continue
        rel  = p.relative_to(FLAKE / 'modules')
        text = strip_comments(p.read_text())
        for block in PKGLIST.findall(text):
            for tok in block.split():
                if PKGNAME.match(tok):
                    found.setdefault(tok, set()).add((str(rel), 'packages'))
        for opt in PROGRAM.findall(text):
            found.setdefault(opt, set()).add((str(rel), 'programs'))
    return found


def our_casks():
    """The cask tokens homebrew.nix installs. Only the `casks = [ ... ]` block:
    `brews` are CLI tools, a different conversation from a GUI app arriving
    twice."""
    block = CASKS.search(strip_comments(HOMEBREW.read_text()))
    return set(re.findall(r'"([a-z0-9@.-]+)"', block.group(1))) if block else set()


def cask_homepages(tokens):
    """token -> normalized homepage, for our casks only.

    Restricting to our tokens is what keeps `vlc@nightly` and `gimp@dev` -- both
    of which share a homepage with the cask we do install -- out of the results.
    """
    if not CASK_API.exists():
        return {}
    payload = json.loads(json.loads(CASK_API.read_text())['payload'])
    return {c['token']: normalize(c.get('homepage'))
            for c in payload if c['token'] in tokens}


def normalize(url):
    url = (url or '').lower()
    url = re.sub(r'^https?://', '', url)
    url = re.sub(r'^www\.', '', url)
    return url.rstrip('/')


def match_cask(pkg, homepage, tokens, homepages):
    """Two independent signals, both exact equality, neither fuzzy.

      name      the cask token IS the package name. Catches the cases where the
                two projects describe the same product with different URLs:
                nixpkgs still has discord at discordapp.com and firefox at
                mozilla.com, Homebrew has discord.com and mozilla.org.
      homepage  same normalized homepage. Catches the cases where the names
                disagree instead: zoom-us/zoom, bitwarden-desktop/bitwarden.

    Nothing here does substring or suffix matching, which both earlier drafts
    tried and both got wrong on their first run -- containment reported
    `obsidian` as the unrelated cask `obs`, and suffix-stripping reported
    `kitty-img`, a separate image tool, as the terminal emulator. A false hit
    argues for deleting a package the machine needs, so this errs toward
    missing a duplicate over inventing one. kitty-img matches neither signal.
    """
    if pkg in tokens:
        return f'{pkg} (name)'
    if homepage:
        for token, hp in sorted(homepages.items()):
            if hp and hp == normalize(homepage):
                return f'{token} (homepage)'
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

DUPLICATE_HELP = '''
Each of these builds fine on {system} AND is installed by a cask, so
nire-lysithea gets two copies. Nothing here is broken -- it is wasted build
time, and for unfree packages it is a live upstream fetch on every build, which
is how a GitHub 503 once failed the whole darwin build for an app Homebrew had
already installed.

`drop-unsupported-packages.nix` will NOT catch these. It reads meta.platforms,
and meta.platforms has no opinion about Homebrew. This needs a decision.

To exclude one, by shape:

  packages  guard the module with lib.mkIf (!pkgs.stdenv.isDarwin), the way
            gui-other/pkm/notes/obsidian.nix does. Read the isDarwin test as
            "on darwin, homebrew.nix owns this app", not "Linux-only".

  programs  do NOT guard the whole module: it usually also generates config
            that the Homebrew copy reads, and guarding throws that away. Check
            whether the HM option is nullable --

                grep -n 'package = ' $(nix eval --raw \\
                  .#inputs.home-manager.outPath)/modules/programs/<name>.nix

            mkPackageOption with { nullable = true; } means `package = null`
            drops the binary and keeps the config, which is what kitty wants.

Leaving one alone is a fine answer too. Homebrew and nixpkgs disagreeing about
a version matters for some apps and not others, and this script does not know
which.
'''


def report_duplicates(system):
    modules   = scan_packages()
    rows      = probe(set(modules), system)
    tokens    = our_casks()
    homepages = cask_homepages(tokens)

    hits = []
    for r in rows:
        if r['verdict'] != 'available':
            continue
        cask = match_cask(r['name'], r['homepage'], tokens, homepages)
        if cask:
            hits.append((r['name'], cask, sorted(modules[r['name']])))

    print(f'{system}\n')
    if not hits:
        print('no packages are installed by both nixpkgs and a homebrew cask.')
        return 0

    w = max(len(n) for n, _, _ in hits)
    print(f'{"PACKAGE":<{w}}  {"CASK":<24}  SHAPE     MODULE')
    for name, cask, places in sorted(hits):
        for i, (path, shape) in enumerate(places):
            head = f'{name:<{w}}  {cask:<24}' if i == 0 else ' ' * (w + 26)
            print(f'{head}  {shape:<8}  {path}')
    # .replace, not .format: the help text contains literal Nix braces
    # (`{ nullable = true; }`) and str.format reads those as fields.
    print(DUPLICATE_HELP.replace('<SYSTEM>', system))
    return 0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('names', nargs='*', help='package attribute paths')
    ap.add_argument('--system', default='aarch64-darwin')
    ap.add_argument('--all', action='store_true',
                    help='derive the list from home.packages across nirePackages/')
    ap.add_argument('--duplicates', action='store_true',
                    help='report packages a homebrew cask ALSO installs, and what to do')
    args = ap.parse_args()

    if args.duplicates:
        if args.names or args.all:
            ap.error('--duplicates sweeps the tree; do not also name packages')
        sys.exit(report_duplicates(args.system))

    names = set(args.names) | (set(scan_packages()) if args.all else set())
    if not names:
        ap.error('name at least one package, or pass --all or --duplicates')

    rows      = probe(names, args.system)
    tokens    = our_casks()
    homepages = cask_homepages(tokens)
    w         = max([len(r['name']) for r in rows] + [7])

    print(f'{args.system}\n')
    if not homepages:
        # Not fatal: the name signal still works anywhere. Said out loud
        # because a silently weaker CASK column reads exactly like a clean one.
        print(f'note: {CASK_API} not found -- cask matching is by name only\n')
    print(f'{"PACKAGE":<{w}}  {"VERDICT":<11}  {"BROKEN":<6}  CASK')
    for r in sorted(rows, key=lambda r: (ORDER.get(r['verdict'], 9), r['name'])):
        print(f'{r["name"]:<{w}}  {r["verdict"]:<11}  '
              f'{"yes" if r["broken"] else "":<6}  '
              f'{match_cask(r["name"], r["homepage"], tokens, homepages)}')


if __name__ == '__main__':
    main()
