"""Compatibility shim for handheld-daemon, which still imports pkg_resources.

setuptools 81 deprecated `pkg_resources` and 83 -- the version nixpkgs carries
as of 2026-08-07 -- no longer ships it at all. handheld-daemon 4.1.10 opens
hhd/__main__.py with `import pkg_resources` and uses it in exactly two places,
so on Python 3.14 the daemon dies on its first line of work:

    ModuleNotFoundError: No module named 'pkg_resources'

Listing setuptools as a dependency does not help, and nixpkgs already does:
the module is gone from setuptools itself, not missing from the closure.

This provides just the one function hhd calls, over importlib.metadata, which
is the supported replacement. The wrapper class exists because the two APIs
disagree on one name -- pkg_resources entry points resolve with .resolve(),
importlib.metadata ones with .load() -- and hhd calls .resolve():

    detectors[autodetect.name] = autodetect.resolve()      # __main__.py:244
    locales.extend(register.resolve()())                   # __main__.py:294

Both are kept, so either spelling works if upstream changes its mind.

Delete this once handheld-daemon stops importing pkg_resources upstream. The
substituteInPlace in jovian.nix uses --replace-fail, so the build will break
loudly rather than silently skipping the patch if that import ever moves.
"""

from importlib.metadata import entry_points


class _EntryPoint:
    """importlib.metadata's EntryPoint, wearing pkg_resources' method names."""

    def __init__(self, ep):
        self._ep = ep
        self.name = ep.name

    def resolve(self):
        return self._ep.load()

    # pkg_resources spelled this .resolve(); importlib.metadata spells it
    # .load(). Answer to both.
    load = resolve


def iter_entry_points(group):
    for ep in entry_points(group=group):
        yield _EntryPoint(ep)
