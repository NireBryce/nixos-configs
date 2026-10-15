#!/usr/bin/env python3
"""Fixture tests for module-graph.py's model and renderers.

The diagram's job is to make the silent cases visible -- a module named like
a category (they merge), a category nothing imports -- so these build small
trees in a temp directory, break them on purpose, and assert the graph says
so. The real tree is clean of both, which would prove nothing about whether
the picture could show them. Pure stdlib; runs via `just module-graph-test`,
part of `just preflight` and CI.
"""
import contextlib, importlib.util, io, pathlib, re, sys, tempfile, unittest

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


class Standard(Tree):
    """The colour standard: a directory with a shim is an importable category;
    a plain directory inside one is an implicit folder; a module is never
    importable, even when a host names it."""

    def setUp(self):
        super().setUp()
        self.write('area/used/grp/c.nix', module('nixos'))
        self.write('area/used/grp/inner/dirsAsCategory.nix', SHIM)
        self.write('area/used/grp/inner/d.nix', module('nixos'))

    def test_plain_directory_is_an_implicit_folder(self):
        g = self.g()
        self.assertEqual(g.nodes['dir:area/used/grp'].kind, 'folder')
        self.assertEqual(g.nodes['dir:area/used/grp'].count, 2)   # c, and inner's d
        contains = self.kinds(g, 'contains')
        self.assertIn(('cat:area/used', 'dir:area/used/grp'), contains)
        self.assertIn(('dir:area/used/grp', 'mod:area/used/grp/c.nix'), contains)
        self.assertIn(('dir:area/used/grp', 'cat:area/used/grp/inner'), contains)
        self.assertNotIn('dir:area/used/grp/inner', g.nodes)      # a category, not a folder

    def test_directories_outside_categories_are_not_folders(self):
        self.write('hosts/sub/e.nix', module('nixos'))
        self.assertNotIn('dir:hosts/sub', self.g().nodes)

    def test_overviews_drop_folders_and_relink_nested_categories(self):
        for view in ('tree', 'hosts'):
            g = mg.select(self.g(), view, categories_only=True)
            self.assertFalse(any(n.kind == 'folder' for n in g.nodes.values()), view)
            self.assertIn(('cat:area/used', 'cat:area/used/grp/inner'), self.kinds(g, 'contains'))

    def test_host_hues_never_reuse_the_category_or_alert_colour(self):
        self.assertNotIn(mg.PALETTE['category'][1], mg.HUES)
        self.assertNotIn(mg.ALERT[1], mg.HUES)

    def test_a_named_module_is_not_drawn_as_importable(self):
        self.write('hosts/beta-configuration.nix', host('nixos', 'c'))
        g = mg.select(self.g(), 'hosts')
        node = g.nodes['mod:area/used/grp/c.nix']
        self.assertEqual(mg.style(node), ['module'])
        self.assertEqual(mg.colours(node), mg.PALETTE['module'])
        out = mg.mermaid(g)
        cid = f'n{list(g.nodes).index("mod:area/used/grp/c.nix")}'
        self.assertNotRegex(out, rf'class [\w,]*\b{cid}\b[\w,]* category')

    def test_renderers_draw_the_two_directory_kinds_apart(self):
        g = mg.select(self.g(), 'tree')
        out = mg.dot(g)
        self.assertRegex(out, r'<b>grp/</b>.*shape=folder')
        self.assertRegex(out, rf'<b>used/</b>.*color="{mg.PALETTE["category"][1]}"')
        m = mg.mermaid(g)
        self.assertIn('["<b>grp/</b>', m)        # square: implicit
        self.assertIn('("<b>inner/</b>', m)      # rounded: importable
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        self.assertIn(f'{ids["dir:area/used/grp"]} -.-> {ids["cat:area/used/grp/inner"]}', m)
        self.assertIn(f'{ids["dir:area/used/grp"]} --> {ids["mod:area/used/grp/c.nix"]}', m)


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
        self.assertFalse(any(e.dst == 'cat:area/lonely' for e in g.edges if e.kind == 'imports'))
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


class HostsLayout(Tree):
    """The hosts view flows down from the hosts, with each host's own
    host-config/ category drawn above it."""

    def setUp(self):
        super().setUp()
        self.write('host-config/alpha/dirsAsCategory.nix', SHIM)
        self.write('host-config/alpha/hw.nix', module('nixos'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'alpha', 'used'))
        self.write('hosts/home.nix', host('homeManager', 'used'))
        self.g_ = mg.select(self.g(), 'hosts')
        self.ids = {i: f'n{k}' for k, i in enumerate(self.g_.nodes)}
        self.agg = self.ids['agg:hosts/alpha-configuration.nix:nixos']
        self.own = self.ids['cat:host-config/alpha']
        self.used = self.ids['cat:area/used']

    def test_mermaid_runs_top_down_with_the_hosts_own_category_above(self):
        out = mg.mermaid(self.g_)
        self.assertIn('\nflowchart TB\n', out)
        self.assertIn(f'{self.own} ~~~ {self.agg}', out)   # ranks it above
        self.assertIn(f'{self.agg} --> {self.own}', out)   # arrow still host -> category
        self.assertIn(f'{self.agg} --> {self.used}', out)  # shared ones flow down

    def test_mermaid_link_styles_count_the_invisible_links(self):
        out = mg.mermaid(self.g_)
        links = [l.strip() for l in out.splitlines()
                 if ' --> ' in l or ' -.-> ' in l or ' ~~~ ' in l or ' -. merges .- ' in l]
        for idx, colour in re.findall(r'linkStyle ([\d,]+) stroke:(#\w+)', out):
            for k in map(int, idx.split(',')):
                self.assertIn(' --> ', links[k], (k, links[k]))   # a coloured edge is a real arrow
        hue = mg.hues(self.g_)['agg:hosts/alpha-configuration.nix:nixos']
        mine = [k for idx, c in re.findall(r'linkStyle ([\d,]+) stroke:(#\w+)', out)
                if c == hue for k in map(int, idx.split(','))]
        self.assertEqual(sorted(links[k] for k in mine),
                         sorted([f'{self.agg} --> {self.own}', f'{self.agg} --> {self.used}']))

    def test_dot_reverses_the_upward_edge_but_keeps_the_arrowhead(self):
        out = mg.dot(self.g_)
        self.assertIn('rankdir=TB', out)
        self.assertRegex(out, rf'{self.own} -> {self.agg} \[dir=back ')
        self.assertRegex(out, rf'{self.agg} -> {self.used} \[color=')

    def test_dot_pins_unimported_shared_categories_below_the_hosts(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/l.nix', module('nixos'))
        g = mg.select(self.g(), 'hosts')
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        out = mg.dot(g)
        self.assertRegex(out, rf'n\d+ -> {ids["cat:area/lonely"]} \[style=invis\]')
        self.assertNotIn(f'-> {ids["cat:area/used"]} [style=invis]', out)   # has an import
        self.assertNotIn(f'-> {ids["cat:host-config/alpha"]} [style=invis]', out)

    def test_tree_view_stays_left_to_right(self):
        out = mg.dot(mg.select(self.g(), 'tree'))
        self.assertIn('rankdir=LR', out)


class Rendering(Tree):
    def test_mermaid_marks_orphans_and_merges(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/lonely.nix', module('nixos'))
        out = mg.mermaid(mg.select(self.g(), 'tree'))
        self.assertTrue(out.startswith('%%{init:'))
        self.assertIn('\nflowchart LR\n', out)
        self.assertIn('subgraph g0["area"]', out)     # an area is a container
        g = mg.select(self.g(), 'tree')
        area = f'n{list(g.nodes).index("area:area")}'
        self.assertNotRegex(out, rf'(?m)^\s+{area} ')   # containment, not arrows
        self.assertIn('-. merges .-', out)
        self.assertRegex(out, r'class [\w,]+ orphan')
        self.assertRegex(out, r'class [\w,]+ merges')
        self.assertIn('<b>a</b><br/><i>n h</i>', out)

    def test_mermaid_hosts_colours_each_hosts_edges(self):
        self.write('hosts/beta-configuration.nix', host('nixos', 'used', 'sub'))
        out = mg.mermaid(mg.select(self.g(), 'hosts'))
        styles = re.findall(r'(?m)^\s+linkStyle ([\d,]+) stroke:(#\w+)', out)
        self.assertEqual(len(styles), 2)                  # one per host
        self.assertNotEqual(styles[0][1], styles[1][1])   # in different hues
        self.assertEqual(sorted(len(s.split(',')) for s, _ in styles), [1, 2])
        self.assertIn('<i>nixos</i>', out)                # class on the host card
        self.assertNotIn('-->|', out)                     # not on every edge

    def test_hosts_view_boxes_nested_categories_in_their_area(self):
        g = mg.select(self.g(), 'hosts')
        (members,) = [m for i, _, m in mg.groups(g) if i == 'area:area']
        self.assertEqual(set(members), {'cat:area/used', 'cat:area/used/sub'})

    def test_dot_without_arrows_lays_areas_out_as_a_grid(self):
        for k in range(6):
            self.write(f'area/c{k}/dirsAsCategory.nix', SHIM)
        out = mg.dot(mg.select(self.g(), 'tree', depth=1, categories_only=True))
        self.assertIn('rankdir=TB', out)
        self.assertEqual(out.count('[style=invis]'), 7 - mg.GRID)

    def test_dot_is_well_formed_and_escaped(self):
        out = mg.dot(mg.select(self.g(), 'hosts'))
        self.assertTrue(out.startswith('digraph modules {') and out.endswith('}'))
        self.assertEqual(out.count('{'), out.count('}'))
        self.assertIn('label=<<b>used/</b><br/><font', out)   # HTML label
        self.assertIn('subgraph cluster_', out)
        self.assertIn('[style=dotted]', out)          # used -> sub nesting

    def test_cli_prints_mermaid(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mg.main(['tree', str(self.root), '--categories-only'])
        self.assertEqual(rc, 0)
        self.assertIn('used/', buf.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=1)
