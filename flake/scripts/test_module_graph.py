#!/usr/bin/env python3
"""Fixture tests for module-graph.py's model and renderers.

The diagram's job is to make the silent cases visible -- a module named like
a category (they merge), a category nothing imports -- so these build small
trees in a temp directory, break them on purpose, and assert the graph says
so. The real tree is clean of both, which would prove nothing about whether
the picture could show them. Pure stdlib; runs via `just module-graph-test`,
part of `just preflight` and CI.
"""
import contextlib, importlib.util, io, pathlib, sys, tempfile, unittest

_spec = importlib.util.spec_from_file_location(
    'module_graph', pathlib.Path(__file__).with_name('module-graph.py'))
mg = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mg)

SHIM = '''{ config, lib, ... }:
let
  shimFile = __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot (dirOf shimFile) + "/_lib/category-collector.nix") {
  inherit config lib shimFile;
}
'''
MOD = '''{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
@DECLS@
}
'''


def module(*classes):
    return MOD.replace('@DECLS@', '\n'.join(
        f'        flake.modules.{c}.${{moduleName}} = {{ }};' for c in classes))


def host(cls, *names):
    return (f'{{ config, ... }}: {{ flake.modules.{cls}.xConfiguration.imports =\n'
            f'    with config.flake.modules.{cls}; [ {" ".join(names)} ]; }}\n')


class Tree(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name) / 'modules'
        self.write('_lib/category-collector.nix', '# the collector\n')
        self.write('area/used/dirsAsCategory.nix', SHIM)
        self.write('area/used/a.nix', module('nixos', 'homeManager'))
        self.write('area/used/sub/dirsAsCategory.nix', SHIM)
        self.write('area/used/sub/b.nix', module('homeManager'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'used'))

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        return p

    def g(self):
        return mg.graph(self.root)

    def cat(self, g, name):
        (n,) = [n for n in g.nodes.values() if n.kind == 'category' and n.label == name]
        return n

    def kinds(self, g, kind):
        return {(e.src, e.dst) for e in g.edges if e.kind == kind}


class Model(Tree):
    def test_containment_classes_and_counts(self):
        g = self.g()
        used, sub = self.cat(g, 'used'), self.cat(g, 'sub')
        self.assertEqual(used.classes, {'nixos', 'homeManager'})
        self.assertEqual((used.count, sub.count), (2, 1))   # nested counts upward
        self.assertEqual(sub.classes, {'homeManager'})
        contains = self.kinds(g, 'contains')
        self.assertIn(('cat:area/used', 'cat:area/used/sub'), contains)
        self.assertIn(('cat:area/used/sub', 'mod:area/used/sub/b.nix'), contains)
        self.assertIn(('cat:area/used', 'mod:area/used/a.nix'), contains)
        self.assertEqual(g.roots, ['area:area', 'area:hosts'])

    def test_underscore_paths_are_not_drawn(self):
        self.write('area/used/_helpers/h.nix', module('nixos'))
        self.assertNotIn('mod:area/used/_helpers/h.nix', self.g().nodes)

    def test_clean_tree_has_no_merges_edges(self):
        g = self.g()
        self.assertEqual(self.kinds(g, 'merges'), set())
        self.assertFalse(any(n.merges for n in g.nodes.values()))

    def test_module_named_like_category_is_shown_merging(self):
        # the `boot` case: a module whose filename is a category's name
        self.write('area/used/sub/used.nix', module('nixos'))
        g = self.g()
        self.assertIn(('mod:area/used/sub/used.nix', 'cat:area/used'), self.kinds(g, 'merges'))
        self.assertTrue(g.nodes['mod:area/used/sub/used.nix'].merges)
        self.assertTrue(self.cat(g, 'used').merges)
        self.assertIn('merges', mg.style(self.cat(g, 'used')))

    def test_same_name_same_class_merges_but_other_class_does_not(self):
        self.write('area/used/x/dup.nix', module('nixos'))
        self.write('area/used/y/dup.nix', module('nixos'))
        self.write('area/used/z/other.nix', module('nixos'))
        self.write('area/used/w/other.nix', module('homeManager'))
        merges = self.kinds(self.g(), 'merges')
        self.assertEqual(merges, {('mod:area/used/x/dup.nix', 'mod:area/used/y/dup.nix')})

    def test_orphan_category_is_flagged(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/l.nix', module('nixos'))
        g = self.g()
        self.assertEqual(self.cat(g, 'lonely').status, 'orphan')
        self.assertIn('orphan', mg.style(self.cat(g, 'lonely')))
        self.assertEqual(self.cat(g, 'used').status, 'imported')
        self.assertEqual(self.cat(g, 'sub').status, 'inherited')   # via its parent

    def test_category_reached_only_through_a_named_module(self):
        self.write('area/never-whole/dirsAsCategory.nix', SHIM)
        self.write('area/never-whole/picked.nix', module('nixos'))
        self.write('area/never-whole/other.nix', module('nixos'))
        self.write('hosts/beta-configuration.nix', host('nixos', 'used', 'picked'))
        g = self.g()
        self.assertEqual(self.cat(g, 'never-whole').status, 'by-module')

    def test_host_edges_carry_the_class_and_missing_names_show(self):
        self.write('hosts/home.nix', host('homeManager', 'sub', 'ghost'))
        g = self.g()
        imports = {(e.src, e.dst, e.cls) for e in g.edges if e.kind == 'imports'}
        self.assertIn(('agg:hosts/alpha-configuration.nix:nixos', 'cat:area/used', 'nixos'), imports)
        self.assertIn(('agg:hosts/home.nix:homeManager', 'cat:area/used/sub', 'homeManager'), imports)
        self.assertEqual(g.nodes['missing:ghost'].kind, 'missing')


class Selecting(Tree):
    def test_depth_and_categories_only(self):
        g = mg.select(self.g(), 'tree', depth=1, categories_only=True)
        self.assertEqual({n.label for n in g.nodes.values() if n.kind == 'category'}, {'used'})
        self.assertFalse(any(n.kind == 'module' for n in g.nodes.values()))
        deep = mg.select(self.g(), 'tree', categories_only=True)
        self.assertIn('sub', {n.label for n in deep.nodes.values()})

    def test_category_filter_roots_at_the_category(self):
        g = mg.select(self.g(), 'tree', category='sub')
        self.assertEqual({n.label for n in g.nodes.values()}, {'sub', 'b'})
        one = mg.select(self.g(), 'tree', category='used', depth=1)
        self.assertEqual({n.label for n in one.nodes.values()}, {'used', 'a', 'sub'})

    def test_unknown_category_is_an_error_naming_the_real_ones(self):
        with self.assertRaises(SystemExit) as cm:
            mg.select(self.g(), 'tree', category='nope')
        self.assertIn('used', str(cm.exception))

    def test_hosts_view_keeps_orphans_and_drops_modules(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/l.nix', module('nixos'))
        g = mg.select(self.g(), 'hosts')
        self.assertIn('cat:area/lonely', g.nodes)        # drawn, with no host edge
        self.assertFalse(any(e.dst == 'cat:area/lonely' for e in g.edges))
        self.assertFalse(any(n.kind == 'module' for n in g.nodes.values()))
        self.assertIn('agg:hosts/alpha-configuration.nix:nixos', g.nodes)

    def test_hosts_view_category_filter_drops_unrelated_hosts(self):
        self.write('area/other/dirsAsCategory.nix', SHIM)
        self.write('area/other/o.nix', module('nixos'))
        self.write('hosts/beta-configuration.nix', host('nixos', 'other'))
        g = mg.select(self.g(), 'hosts', category='other')
        aggs = {n.label for n in g.nodes.values() if n.kind == 'aggregate'}
        self.assertEqual(aggs, {'beta-configuration'})

    def test_hosts_view_draws_a_module_a_host_names(self):
        self.write('area/never-whole/dirsAsCategory.nix', SHIM)
        self.write('area/never-whole/picked.nix', module('nixos'))
        self.write('hosts/beta-configuration.nix', host('nixos', 'picked'))
        g = mg.select(self.g(), 'hosts')
        self.assertIn('mod:area/never-whole/picked.nix', g.nodes)


class Rendering(Tree):
    def test_mermaid_marks_orphans_and_merges(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/lonely.nix', module('nixos'))
        out = mg.mermaid(mg.select(self.g(), 'tree'))
        self.assertTrue(out.startswith('flowchart LR\n'))
        self.assertIn('-. merges .-', out)
        self.assertRegex(out, r'class [\w,]+ orphan')
        self.assertRegex(out, r'class [\w,]+ merges')
        self.assertIn('a<br/>n h', out)

    def test_mermaid_hosts_labels_edges_with_the_class_letter(self):
        out = mg.mermaid(mg.select(self.g(), 'hosts'))
        self.assertRegex(out, r'n\d+ -->\|n\| n\d+')

    def test_dot_is_well_formed_and_escaped(self):
        out = mg.dot(mg.select(self.g(), 'hosts'))
        self.assertTrue(out.startswith('digraph modules {') and out.endswith('}'))
        self.assertEqual(out.count('{'), out.count('}'))
        self.assertNotIn('<br/>', out)
        self.assertIn('[style=dotted]', out)          # used -> sub nesting

    def test_cli_prints_mermaid(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mg.main(['tree', str(self.root), '--categories-only'])
        self.assertEqual(rc, 0)
        self.assertIn('used/', buf.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=1)
