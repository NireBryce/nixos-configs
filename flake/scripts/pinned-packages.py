#!/usr/bin/env python3
"""Keep the hand-pinned packages current, or notice when they stop needing to be.

A few packages here are fetched straight from upstream because nothing else
packages them -- a version and hashes written into the module by hand. A pin
nobody bumps goes stale silently, and a pin that outlives the reason for it
(nixpkgs or llm-agents starting to package the tool) is upkeep for nothing.
Skill `pinned-packages` is the procedure around this script.

    pinned-packages.py                  # same as `check`
    pinned-packages.py check
    pinned-packages.py bump zai-coding-helper
    pinned-packages.py bump --all

`check` answers two questions per pin, and exits 1 if either wants action:

  packaged elsewhere?   attribute names matching the pin's pattern, in nixpkgs
                        and in llm-agents -- each both at the flake's LOCKED
                        rev and at the branch head. A hit at head only means a
                        `nix flake update` gets it. A name match is a
                        candidate, not proof: read the package before switching.

  current?              the pinned version against upstream's own channel
                        (the npm package's "latest" dist-tag).

`bump` rewrites the module (and, for the npm package, regenerates its trimmed
package.json and lockfile), then builds the result and runs its --version.
It needs network, nix, and -- for the npm package -- nothing on PATH: node and
prefetch-npm-deps come from the flake's own nixpkgs via `nix shell`.

The rewrites are regex-coupled to the modules' exact shapes; test_pinned_packages.py
holds them to it.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

HERE  = pathlib.Path(__file__).resolve().parent
FLAKE = HERE.parent
AI    = FLAKE / 'modules/packages-config/development/tools/ai-tools'

ZAI_NPM           = '@z_ai/coding-helper'

PINS = {
    'zai-coding-helper': {
        'module':  AI / 'zai-coding-helper.nix',
        'pattern': r'(z[-_]?ai.*(coding|helper))|chelper|coding-helper',
        'binary':  'chelper',
    },
}
ZAI_PACKAGE_JSON = AI / 'zai-coding-helper-package.json'
ZAI_LOCK         = AI / 'zai-coding-helper-package-lock.json'

# Where "packaged elsewhere" is looked for: (label, flake input name, head ref,
# attribute path under the flake's outputs, with {system} filled in).
SOURCES = [
    ('nixpkgs',    'nixpkgs',    'github:NixOS/nixpkgs/nixos-unstable', 'legacyPackages.{system}'),
    ('llm-agents', 'llm-agents', 'github:numtide/llm-agents.nix',       'packages.{system}'),
]


# ── network ─────────────────────────────────────────────────────────────────

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'nixos-configs-pinned-packages'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def fetch_json(url):
    return json.loads(fetch(url))


def zai_upstream():
    return fetch_json(f'https://registry.npmjs.org/{ZAI_NPM}')['dist-tags']['latest']


UPSTREAM = {'zai-coding-helper': zai_upstream}


# ── reading and rewriting the modules ───────────────────────────────────────

VERSION_RE = re.compile(r'^(\s*version\s*=\s*")([^"]*)(";)', re.M)


def pinned_version(text):
    m = VERSION_RE.search(text)
    if not m:
        sys.exit('pinned-packages: no `version = "...";` line found')
    return m.group(2)


def _sub_once(pattern, repl, text, what):
    new, n = re.subn(pattern, repl, text, flags=re.M)
    if n != 1:
        sys.exit(f'pinned-packages: expected exactly one {what}, found {n} -- module shape changed?')
    return new


def set_version(text, version):
    return _sub_once(VERSION_RE.pattern, lambda m: m.group(1) + version + m.group(3), text, 'version line')


def rewrite_zai(text, version, src_hash, deps_hash):
    text = set_version(text, version)
    text = _sub_once(r'(^\s*hash\s*=\s*")[^"]*(")', lambda m: m.group(1) + src_hash + m.group(2), text, 'src hash')
    text = _sub_once(r'(^\s*npmDepsHash\s*=\s*")[^"]*(")', lambda m: m.group(1) + deps_hash + m.group(2), text, 'npmDepsHash')
    return text


def trimmed_package_json(pkg):
    """Upstream's package.json minus devDependencies -- see zai-coding-helper.nix for why both files are trimmed."""
    return {k: v for k, v in pkg.items() if k != 'devDependencies'}


# ── nix ─────────────────────────────────────────────────────────────────────

def run(cmd, **kw):
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        sys.exit(f'pinned-packages: {" ".join(cmd[:4])}... failed:\n{r.stderr.strip()}')
    return r.stdout


def current_system():
    return run(['nix', 'eval', '--impure', '--raw', '--expr', 'builtins.currentSystem'])


def attr_names(flake_ref_expr, attrpath):
    expr = f'builtins.attrNames ({flake_ref_expr}).{attrpath}'
    return json.loads(run(['nix', 'eval', '--impure', '--json', '--expr', expr]))


def packaged_elsewhere(system):
    """{pin: [(where, attr), ...]} for every source x {locked, head}."""
    found = {name: [] for name in PINS}
    for label, input_name, head, attrpath in SOURCES:
        path = attrpath.format(system=system)
        refs = [('locked', f'(builtins.getFlake "{FLAKE}").inputs.{input_name}'),
                ('head',   f'builtins.getFlake "{head}"')]
        for when, ref in refs:
            names = attr_names(ref, path)
            for name, pin in PINS.items():
                for attr in names:
                    if re.search(pin['pattern'], attr, re.I):
                        found[name].append((f'{label} ({when})', attr))
    return found


def nix_shell(pkgs, cmd, **kw):
    installables = [f'nixpkgs#{p}' for p in pkgs]
    return run(['nix', 'shell', '--inputs-from', str(FLAKE), *installables, '-c', *cmd], **kw)


def build_and_version(name):
    """Build the pin through this host's evaluated Home Manager config, then run its --version."""
    pin = PINS[name]
    host = run(['hostname']).strip()
    klass = 'darwinConfigurations' if sys.platform == 'darwin' else 'nixosConfigurations'
    expr = (f'let c = (builtins.getFlake "{FLAKE}").{klass}.{host}.config; in '
            f'builtins.head (builtins.filter (p: (p.pname or "") == "{name}") '
            f'c.home-manager.users.elly.home.packages)')
    out = run(['nix', 'build', '--impure', '--no-link', '--print-out-paths', '--expr', expr]).strip()
    print(f'  built {out}')
    # Reported, not enforced: a CLI without --version is not a failed bump.
    r = subprocess.run([f'{out}/bin/{pin["binary"]}', '--version'], capture_output=True, text=True)
    print(f'  {pin["binary"]} --version (exit {r.returncode}): {(r.stdout or r.stderr).strip()[:200]}')


# ── commands ────────────────────────────────────────────────────────────────

def cmd_check(_args):
    system = current_system()
    elsewhere = packaged_elsewhere(system)
    action = False
    for name, pin in PINS.items():
        have = pinned_version(pin['module'].read_text())
        want = UPSTREAM[name]()
        state = 'current' if have == want else 'BUMP'
        print(f'{name:20} pinned {have:16} upstream {want:16} {state}')
        for where, attr in elsewhere[name]:
            print(f'  packaged in {where}: {attr}   -- read it; switching to it retires this pin')
        action |= state != 'current' or bool(elsewhere[name])
    return 1 if action else 0


def bump_zai():
    module = PINS['zai-coding-helper']['module']
    version = zai_upstream()
    meta = fetch_json(f'https://registry.npmjs.org/{ZAI_NPM}/{version}')
    src_hash = meta['dist']['integrity']
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        tgz = tmp / 'pkg.tgz'
        tgz.write_bytes(fetch(meta['dist']['tarball']))
        with tarfile.open(tgz) as t:
            pkg = json.load(t.extractfile('package/package.json'))
        pkg_json = json.dumps(trimmed_package_json(pkg), indent=2) + '\n'
        work = tmp / 'work'
        work.mkdir()
        (work / 'package.json').write_text(pkg_json)
        print('  regenerating package-lock.json (dependencies only)')
        nix_shell(['nodejs'], ['npm', 'install', '--package-lock-only', '--ignore-scripts',
                               '--no-audit', '--no-fund'], cwd=work)
        lock = (work / 'package-lock.json').read_text()
        deps_hash = nix_shell(['prefetch-npm-deps'], ['prefetch-npm-deps', str(work / 'package-lock.json')]).strip().splitlines()[-1]
    ZAI_PACKAGE_JSON.write_text(pkg_json)
    ZAI_LOCK.write_text(lock)
    module.write_text(rewrite_zai(module.read_text(), version, src_hash, deps_hash))
    return version


BUMP = {'zai-coding-helper': bump_zai}


def cmd_bump(args):
    names = list(PINS) if args.all else args.names
    if not names:
        sys.exit('pinned-packages bump: name a pin, or --all')
    for name in names:
        if name not in PINS:
            sys.exit(f'pinned-packages: unknown pin {name!r} (known: {", ".join(PINS)})')
        have = pinned_version(PINS[name]['module'].read_text())
        print(f'{name}: pinned {have}')
        new = BUMP[name]()
        print(f'  rewrote to {new}')
        build_and_version(name)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest='cmd')
    sub.add_parser('check', help='report staleness and upstream packaging (default)')
    b = sub.add_parser('bump', help='rewrite pins to upstream, then build them')
    b.add_argument('names', nargs='*')
    b.add_argument('--all', action='store_true')
    args = ap.parse_args()
    sys.exit(cmd_bump(args) if args.cmd == 'bump' else cmd_check(args))


if __name__ == '__main__':
    main()
