#!/usr/bin/env python3
"""Fixture tests for modules.py's shim detection and its `names`/`shims` checks.

Both checks exist for failures that produce no error anywhere else: a module
declared under a hardcoded name that isn't its filename is simply in no
category, and a shim renamed out of step with the others simply stops being
seen as a nested category. Against the real tree both come back clean, which
proves nothing about whether they'd fire -- so this builds small module trees
in a temp directory, breaks them on purpose, and asserts each check reports
exactly the broken file. Also pins that shims are found by what they import
(not by name) and that `_`-prefixed paths are ignored, matching import-tree
and the collector. Pure stdlib; runs via `just modules-test`, part of
`just preflight` and CI.
"""
import contextlib, io, pathlib, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import modules  # noqa: E402

SHIM = '''{ config, lib, ... }:
let
  shimFile = __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot (dirOf shimFile) + "/_lib/category-collector.nix") {
  inherit config lib shimFile;
}
'''
GOOD = '''{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { };
}
'''


def quiet(fn, *args):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*args)


class Tree(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name) / 'modules'
        self.write('_lib/category-collector.nix', '# the collector\n')
        self.write('area/cat/dirsAsCategory.nix', SHIM)
        self.write('area/cat/nested/dirsAsCategory.nix', SHIM)
        self.write('area/cat/group/good.nix', GOOD)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p

    def test_clean_tree_has_no_findings(self):
        self.assertEqual(quiet(modules.names, self.root), [])
        self.assertEqual(quiet(modules.shims, self.root), [])

    def test_shims_found_by_content_not_name(self):
        self.write('area/other/anything.nix', SHIM)
        cats, _ = modules.scan(self.root)
        self.assertEqual(set(cats), {'cat', 'nested', 'other'})

    def test_underscore_paths_ignored(self):
        self.write('area/cat/_helpers/helper.nix', GOOD)
        self.write('_templates/dirsAsCategory.nix', SHIM)
        cats, mods = modules.scan(self.root)
        self.assertNotIn('_templates', cats)
        self.assertNotIn('helper', mods)

    def test_names_reports_hardcoded_mismatch(self):
        bad = self.write('area/cat/group/foo.nix',
                         '{ ... }: { flake.modules.nixos.bar = { }; }\n')
        hits = quiet(modules.names, self.root)
        self.assertEqual([(h[0], h[2]) for h in hits], [(bad, 'bar')])

    def test_names_ignores_references_and_entry_points(self):
        # a reference to another module is not a declaration...
        self.write('area/cat/group/refs.nix',
                   '{ config, ... }: { flake.modules.nixos.refs.imports = '
                   '[ config.flake.modules.nixos.good ]; }\n')
        # ...and an entry point outside every category names itself by hand
        self.write('area/hostConfiguration.nix',
                   '{ ... }: { flake.modules.nixos.hostConfiguration = { }; }\n')
        self.write('area/host-configuration.nix',
                   '{ ... }: { flake.modules.nixos.hostConfiguration = { }; }\n')
        self.assertEqual(quiet(modules.names, self.root), [])

    def test_shims_reports_a_renamed_shim(self):
        (self.root / 'area/cat/nested/dirsAsCategory.nix').rename(
            self.root / 'area/cat/nested/renamed.nix')
        self.write('area/third/dirsAsCategory.nix', SHIM)
        hits = quiet(modules.shims, self.root)
        self.assertEqual(hits, [self.root / 'area/cat/nested/renamed.nix'])

    def test_shims_reports_drifted_contents(self):
        self.write('area/third/dirsAsCategory.nix', SHIM)
        drifted = self.write('area/cat/nested/dirsAsCategory.nix',
                             '# a local tweak\n' + SHIM)
        hits = quiet(modules.shims, self.root)
        self.assertEqual(hits, [drifted])

    def test_all_shims_renamed_together_is_fine(self):
        for rel in ('area/cat', 'area/cat/nested'):
            (self.root / rel / 'dirsAsCategory.nix').rename(
                self.root / rel / 'category.nix')
        self.assertEqual(quiet(modules.shims, self.root), [])
        cats, _ = modules.scan(self.root)
        self.assertEqual(set(cats), {'cat', 'nested'})


if __name__ == '__main__':
    unittest.main(verbosity=1)
