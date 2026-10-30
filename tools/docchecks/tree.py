"""The tree reader the doc checks, generated regions and `just modules`
share.

Thin wrapper over wiki/meta/scripts/nixtree.py -- the one static reading
of the dirs-as-categories tree, which wiki_gen.py also imports, so the
checks, the generator and the module tooling cannot disagree about what
the files say. nixtree.py exists to run without nix and on fixture trees;
nothing here evaluates.

Import-agnostic on purpose: flake/scripts/modules.py loads this module
bare (no factcheck on its path), so anything that needs the factcheck
package -- the `counts` counters in roster.py, the checks and regions --
lives in its own plugin file and is loaded by the CLI only.
"""
import pathlib
import sys

_here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(_here.parents[1] / 'wiki' / 'meta' / 'scripts'))
import nixtree  # noqa: E402

# Re-exported: the checks and regions read the tree through this module.
from nixtree import (  # noqa: E402,F401
    actual_hosts, all_categories, categories_under, category_classes,
    find_categories, static_document)

PREFIX = 'nire-'


def roster(root):
    """(host short names in hosts.nix order, the NixOS-class ones as a
    set). A short name is the `nire-` name without its prefix, which is
    how a host's `<short>-configuration.nix` and the wiki's Imported by
    columns write it. Read from hosts.nix, so adding or removing a host
    needs no edit here."""
    hosts = actual_hosts(root)
    short = lambda name: name.removeprefix(PREFIX)
    return ([short(n) for n in hosts],
            {short(n) for n, cls in hosts.items() if cls == 'nixos'})


def host_imports(root, categories, hosts=None):
    """nixtree.host_imports over hosts.nix's roster unless the caller
    names one."""
    return nixtree.host_imports(
        root, categories, roster(root)[0] if hosts is None else hosts)
