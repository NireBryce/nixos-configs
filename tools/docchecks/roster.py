"""The counters behind `counts`' "all N hosts" claims: registered here so
the roster is read in exactly one place (tree.py, which wraps nixtree).
A plugin file rather than part of tree.py because tree.py is also loaded
bare by flake/scripts/modules.py, outside the factcheck CLI."""
from factcheck.checks.counts import register_counter

import tree


@register_counter('total')
def _total(root, cfg):
    return len(tree.actual_hosts(root))


@register_counter('nixos')
def _nixos(root, cfg):
    return sum(1 for c in tree.actual_hosts(root).values() if c == 'nixos')


@register_counter('darwin')
def _darwin(root, cfg):
    return sum(1 for c in tree.actual_hosts(root).values() if c == 'darwin')
