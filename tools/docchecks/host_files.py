"""host_files: comments in a host's `<host>-configuration.nix` that name
`host-config/` directories or `<module>-<host>` module files must name
things that exist.

It catches a comment left naming a renamed or deleted module (the
`vms/` to `cube-vm/` rename, a removed `disko-cube.nix`). It reads the
comments, not the Nix code, so a module list in a comment is checked
the same way the code is.

For each file matching `files` in `dir`, whose host short name (from
hosts.nix, through tree.roster) is the filename minus `-configuration`,
the comment text (from the first `#` on each line) is searched for:

  * `host-config/<path>`: the path must exist under `dir`, as a
    directory or a file. Trailing `.`, `,`, `:` and `)` are not part of
    it.
  * a module token `<word>(-<word>)*-<host>` with the file's own host,
    optionally followed by `.nix`: some `<token>.nix` must exist under
    `dir/<host>/`, at any depth.

Not module tokens, and never flagged: a token starting with one of
`skip-prefixes` (`nire-<host>` is a hostname, `ts-<host>` a tailnet
device name), and tokens naming another host (`hardware-durandal` in
tenacity's file): each host's own file is checked against its own
directory only. A file whose host is not in hosts.nix
(forge-runner-configuration.nix, a guest) is skipped.

Config (`[host_files]`):

    [host_files]
    dir = "flake/modules/host-config"
    files = "*-configuration.nix"
    skip-prefixes = ["nire-", "ts-"]
"""
import re

from factcheck.findings import Finding
from factcheck.registry import check

import tree

DIR_REF = re.compile(r'host-config/([\w./-]*[\w/])')


def comment_lines(text):
    """[(line number, comment text)] for every line holding a `#`."""
    out = []
    for number, line in enumerate(text.splitlines(), 1):
        _, hash_mark, comment = line.partition('#')
        if hash_mark:
            out.append((number, comment))
    return out


@check('host_files', order=80)
def check_host_files(root, cfg):
    section = cfg.section('host_files')
    base = root / section.get('dir', 'flake/modules/host-config')
    pattern = section.get('files', '*-configuration.nix')
    skip_prefixes = tuple(section.get('skip-prefixes', ['nire-', 'ts-']))
    hosts = set(tree.roster(root)[0])
    findings = []
    for path in sorted(base.glob(pattern)):
        host = path.name.removesuffix('.nix').removesuffix('-configuration')
        if host not in hosts:
            continue
        module_rx = re.compile(
            r'(?<![\w@-])((?:[A-Za-z][\w]*-)+' + re.escape(host) + r')(?:\.nix)?(?![\w-])')
        own_files = {file.stem for file in (base / host).rglob('*.nix')}
        for number, comment in comment_lines(path.read_text()):
            for match in DIR_REF.finditer(comment):
                ref = match.group(1).rstrip('/')
                if not (base / ref).exists():
                    findings.append(Finding(
                        'UNKNOWN DIR', f'{path}:{number}',
                        f"comment names 'host-config/{ref}' but nothing "
                        f"exists at {base.name}/{ref}"))
            for match in module_rx.finditer(comment):
                token = match.group(1)
                if token.startswith(skip_prefixes):
                    continue
                if token not in own_files:
                    findings.append(Finding(
                        'UNKNOWN MODULE', f'{path}:{number}',
                        f"comment names '{token}' but there is no "
                        f"{token}.nix under {base.name}/{host}/"))
    return findings
