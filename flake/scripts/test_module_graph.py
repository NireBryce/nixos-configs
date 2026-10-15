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
        self.assertRegex(out, rf'label=<<b>used/</b>.*\n.*color="{mg.PALETTE["category"][1]}"')
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
        self.sub = self.ids['cat:area/used/sub']   # first in used's box: where its edges land

    def test_mermaid_runs_top_down_with_the_hosts_own_category_above(self):
        out = mg.mermaid(self.g_)
        self.assertIn('\nflowchart TB\n', out)
        self.assertIn(f'{self.own} --- {self.agg}', out)   # category-first: ranks it above
        self.assertNotIn(f'{self.agg} --> {self.own}', out)   # no arrow back: no cycle
        box = re.search(r'subgraph (g\d+)\["<b>used/</b>', out).group(1)
        self.assertIn(f'{self.agg} --> {box}', out)        # shared ones flow down, into the box

    def test_mermaid_link_styles_land_on_the_hosts_own_edges(self):
        out = mg.mermaid(self.g_)
        links = [l.strip() for l in out.splitlines()
                 if re.search(r' (-->|-\.->|---|~{3,}|-\. merges \.-) ', l)]
        for idx, colour in re.findall(r'linkStyle ([\d,]+) stroke:(#\w+)', out):
            for k in map(int, idx.split(',')):
                self.assertNotIn('~', links[k], (k, links[k]))   # never an invisible link
        hue = mg.hues(self.g_)['agg:hosts/alpha-configuration.nix:nixos']
        mine = [k for idx, c in re.findall(r'linkStyle ([\d,]+) stroke:(#\w+)', out)
                if c == hue for k in map(int, idx.split(','))]
        box = re.search(r'subgraph (g\d+)\["<b>used/</b>', out).group(1)
        self.assertEqual(sorted(links[k] for k in mine),
                         sorted([f'{self.own} --- {self.agg}', f'{self.agg} --> {box}']))

    def test_dot_reverses_the_upward_edge_but_keeps_the_arrowhead(self):
        out = mg.dot(self.g_)
        self.assertIn('rankdir=TB', out)
        self.assertRegex(out, rf'{self.own} -> {self.agg} \[dir=back ')
        self.assertRegex(out, rf'{self.agg} -> {self.sub} \[color=[^\]]* lhead=cluster_\d+\]')

    def test_dot_pins_unimported_shared_categories_below_the_hosts(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/l.nix', module('nixos'))
        g = mg.select(self.g(), 'hosts')
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        out = mg.dot(g)
        self.assertRegex(out, rf'n\d+ -> {ids["cat:area/lonely"]} \[style=invis minlen=1\]')
        self.assertNotRegex(out, rf'-> {ids["cat:host-config/alpha"]} \[style=invis')   # above, not below

    def test_users_config_sits_above_the_hosts_too(self):
        self.write('users-config/u/dirsAsCategory.nix', SHIM)
        self.write('users-config/u/acct.nix', module('nixos'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'alpha', 'u', 'used'))
        g = mg.select(self.g(), 'hosts')
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        agg = ids['agg:hosts/alpha-configuration.nix:nixos']
        out = mg.dot(g)
        self.assertIn(f'{ids["cat:users-config/u"]} -> {agg} [dir=back', out)
        self.assertIn(f'{ids["cat:host-config/alpha"]} -> {agg} [dir=back', out)
        self.assertRegex(out, rf'{agg} -> {ids["cat:area/used/sub"]} \[color=[^\]]* lhead=')

    def test_tree_view_stays_left_to_right(self):
        out = mg.dot(mg.select(self.g(), 'tree'))
        self.assertIn('rankdir=LR', out)


class Wrapping(Tree):
    """Shared areas wrap at `wrap` categories per row; each row sits far
    enough below the last to clear its nested categories."""

    def setUp(self):
        super().setUp()
        tops = [f'c{k}' for k in range(7)]
        for c in tops:
            self.write(f'area/{c}/dirsAsCategory.nix', SHIM)
            self.write(f'area/{c}/m.nix', module('nixos'))
        for k in range(6):                       # c0 has six nested: two rows at wrap 5
            self.write(f'area/c0/k{k}/dirsAsCategory.nix', SHIM)
        self.write('hosts/alpha-configuration.nix', host('nixos', *tops, 'used'))
        self.g_ = mg.select(self.g(), 'hosts')

    def links(self, wrap=5):
        return {b.split(':')[-1]: n for _, b, n in mg.layout_links(self.g_, wrap)}

    def test_every_card_gets_its_rank_below_the_hosts(self):
        # top row c0..c4, then c5 c6 used. c0 is a box holding k0..k4 then
        # k5, and takes no rank of its own: its rows start at 1, so the
        # area's next row starts at 1 + 2.
        self.assertEqual(self.links(), {
            'area/c0/k0': 1, 'area/c0/k1': 1, 'area/c0/k2': 1, 'area/c0/k3': 1,
            'area/c0/k4': 1, 'area/c0/k5': 2,
            'area/c1': 1, 'area/c2': 1, 'area/c3': 1, 'area/c4': 1,
            'area/c5': 3, 'area/c6': 3, 'area/used/sub': 3})

    def test_links_all_start_at_the_first_host(self):
        self.assertEqual({a for a, _, _ in mg.layout_links(self.g_)},
                         {'agg:hosts/alpha-configuration.nix:nixos'})

    def test_wrap_zero_is_one_row(self):
        self.assertEqual(set(self.links(0).values()), {1})

    def test_dot_keeps_every_host_on_one_row(self):
        self.write('hosts/beta-configuration.nix', host('nixos', 'c6'))
        g = mg.select(self.g(), 'hosts')
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        aggs = [ids[i] for i, n in g.nodes.items() if n.kind == 'aggregate']
        self.assertEqual(len(aggs), 2)
        self.assertIn('{ rank=same; ' + ' '.join(aggs) + ' }', mg.dot(g))

    def test_tree_view_is_never_wrapped(self):
        self.assertEqual(mg.layout_links(mg.select(self.g(), 'tree')), [])

    def test_renderers_draw_the_same_links(self):
        g = self.g_
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        a, b = ids['agg:hosts/alpha-configuration.nix:nixos'], ids['cat:area/c5']
        self.assertIn(f'{a} -> {b} [style=invis minlen=3];', mg.dot(g))
        self.assertIn(f'{a} ~~~~~ {b}', mg.mermaid(g))       # 3 tildes is 1 rank, +1 per rank

    def test_cli_wrap_flag_reaches_the_renderer(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            mg.main(['dot', str(self.root), '--view', 'hosts', '--wrap', '0', '--static'])
        self.assertNotIn('minlen=3', buf.getvalue())


class Boxes(Tree):
    """A category holding a nested category is drawn as a box around it."""

    def test_only_a_category_with_a_nested_category_is_boxed(self):
        g = mg.select(self.g(), 'tree')
        self.assertEqual(mg.boxed(g), {'cat:area/used'})        # sub holds only b

    def test_the_box_holds_its_whole_subtree(self):
        g = mg.select(self.g(), 'tree')
        (used,) = [b for b in mg.walk(mg.boxes(g)) if b.id == 'cat:area/used']
        self.assertEqual(set(used.items), {'mod:area/used/a.nix', 'cat:area/used/sub',
                                           'mod:area/used/sub/b.nix'})
        self.assertEqual(set(used.top), {'mod:area/used/a.nix', 'cat:area/used/sub'})  # direct only

    def test_containment_is_the_box_not_an_arrow(self):
        g = mg.select(self.g(), 'tree')
        self.assertFalse(any(e.src == 'cat:area/used' for e in mg.arrows(g)))
        self.assertIn(('cat:area/used/sub', 'mod:area/used/sub/b.nix'),
                      {(e.src, e.dst) for e in mg.arrows(g)})   # sub is a card: arrows stay

    def test_a_box_is_not_also_drawn_as_a_card(self):
        g = mg.select(self.g(), 'hosts')
        ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
        self.assertNotRegex(mg.dot(g), rf'(?m)^\s+{ids["cat:area/used"]} \[')
        self.assertNotRegex(mg.mermaid(g), rf'(?m)^\s+{ids["cat:area/used"]}\(')

    def test_box_status_styling(self):
        self.write('area/lonely/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/inner/dirsAsCategory.nix', SHIM)
        self.write('area/lonely/inner/l.nix', module('nixos'))
        self.write('area/picked/dirsAsCategory.nix', SHIM)
        self.write('area/picked/inner2/dirsAsCategory.nix', SHIM)
        self.write('area/picked/inner2/p.nix', module('nixos'))
        self.write('hosts/beta-configuration.nix', host('nixos', 'p'))
        out = mg.dot(mg.select(self.g(), 'hosts'))
        lonely = re.search(r'label=<<b>lonely/</b>.*\n(.*)', out).group(1)
        self.assertIn(f'color="{mg.ALERT[1]}"', lonely)
        self.assertIn('penwidth=2.5', lonely)
        picked = re.search(r'label=<<b>picked/</b>.*\n(.*)', out).group(1)
        self.assertIn('dashed', picked)                          # reached by module only
        m = mg.mermaid(mg.select(self.g(), 'hosts'))
        self.assertRegex(m, rf'style g\d+ fill:{mg.BOX_FILL},stroke:{mg.ALERT[1]}.*stroke-width:2.5px')


class FakeNix:
    """Stands in for subprocess.run: answers `nix eval --json <ref>#<attr>`
    from a dict, so evaluation is tested without nix. A value of None makes
    that attribute fail to evaluate; `missing=True` acts as if nix is absent."""

    def __init__(self, answers, missing=False):
        self.answers, self.missing, self.calls = answers, missing, []

    def __call__(self, cmd, **kw):
        import json, types
        self.calls.append(cmd)
        if self.missing:
            raise FileNotFoundError('nix')
        attr = cmd[3].split('#', 1)[1]
        value = self.answers.get(attr)
        if value is None:
            return types.SimpleNamespace(returncode=1, stdout='',
                                         stderr=f"error: flake has no attribute '{attr}'\n")
        if '--apply' in cmd:
            value = sorted(value)
        return types.SimpleNamespace(returncode=0, stdout=json.dumps(value), stderr='')


class Evaluated(Tree):
    """Categories from flake.categoryGraph instead of the static scan."""

    def truth(self):
        return mg.static_categories(self.root)

    def test_static_categories_in_categorygraph_shape(self):
        self.write('area/used/grp/c.nix', module('nixos'))
        self.assertEqual(self.truth(), {
            'used': {'dir': 'area/used', 'files': ['area/used/a.nix', 'area/used/grp/c.nix'],
                     'nested': ['sub']},
            'sub': {'dir': 'area/used/sub', 'files': ['area/used/sub/b.nix'], 'nested': []}})

    def test_matching_evaluation_draws_the_same_graph(self):
        static, evald = mg.graph(self.root), mg.graph(self.root, self.truth())
        self.assertEqual(static.nodes, evald.nodes)
        self.assertEqual(static.edges, evald.edges)

    def test_the_collector_decides_what_is_a_category(self):
        # evaluation knows no `sub`: its folder is drawn as a plain folder
        evaluated = self.truth()
        del evaluated['sub']
        g = mg.graph(self.root, evaluated)
        self.assertEqual(g.nodes['dir:area/used/sub'].kind, 'folder')
        self.assertNotIn('cat:area/used/sub', g.nodes)

    def test_compare_finds_every_kind_of_disagreement(self):
        s = self.truth()
        self.assertEqual(mg.compare_categories(s, self.truth()), [])
        e = self.truth()
        e['used']['files'].remove('area/used/a.nix')
        e['used']['nested'] = []
        e['sub']['dir'] = 'area/elsewhere'
        e['ghost'] = {'dir': 'area/ghost', 'files': [], 'nested': []}
        hits = mg.compare_categories(s, e)
        self.assertEqual(len(hits), 4, hits)
        joined = '\n'.join(hits)
        for needle in ("'ghost'", 'area/used/a.nix is collected only per the parse',
                       "nested 'sub' only per the parse", 'evaluated at area/elsewhere'):
            self.assertIn(needle, joined)

    def test_evaluate_reports_why_it_failed(self):
        self.assertEqual(mg.evaluated_categories(self.root, FakeNix({'categoryGraph': {'x': 1}})),
                         ({'x': 1}, None))
        value, why = mg.evaluated_categories(self.root, FakeNix({}))
        self.assertIsNone(value)
        self.assertIn("no attribute 'categoryGraph'", why)
        self.assertEqual(mg.evaluated_categories(self.root, FakeNix({}, missing=True)),
                         (None, 'nix is not installed'))

    def test_evaluate_uses_a_path_ref(self):
        fake = FakeNix({'categoryGraph': {}})
        mg.evaluated_categories(self.root, fake)
        self.assertTrue(fake.calls[0][3].startswith('path:'), fake.calls[0])

    def test_cli_falls_back_to_the_static_parse_and_says_so(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = mg.main(['tree', str(self.root)], run=FakeNix({}))
        self.assertEqual(rc, 0)
        self.assertIn('used/', out.getvalue())
        self.assertIn('static parse', err.getvalue())

    def test_cli_static_never_evaluates(self):
        fake = FakeNix({})
        with contextlib.redirect_stdout(io.StringIO()):
            mg.main(['tree', str(self.root), '--static'], run=fake)
        self.assertEqual(fake.calls, [])

    def test_cli_draws_from_the_evaluation(self):
        evaluated = self.truth()
        del evaluated['sub']
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            mg.main(['tree', str(self.root)], run=FakeNix({'categoryGraph': evaluated}))
        self.assertIn('["<b>sub/</b>', out.getvalue())       # square: a folder now

    def test_verify_reports_membership_disagreement(self):
        evaluated = self.truth()
        evaluated['used']['nested'] = []
        names = {'nixos': ['used', 'sub', 'a'], 'homeManager': ['used', 'sub', 'a', 'b'],
                 'darwin': ['used', 'sub']}
        fake = FakeNix({'categoryGraph': evaluated,
                        **{f'modules.{c}': v for c, v in names.items()}})
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            rc = mg.main(['tree', str(self.root), '--static', '--verify'], run=fake)
        self.assertEqual(rc, 1)
        self.assertIn("nested 'sub' only per the parse", err.getvalue())

    def test_verify_clean_when_everything_agrees(self):
        names = {'nixos': ['used', 'sub', 'a'], 'homeManager': ['used', 'sub', 'a', 'b'],
                 'darwin': ['used', 'sub']}
        fake = FakeNix({'categoryGraph': self.truth(),
                        **{f'modules.{c}': v for c, v in names.items()}})
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            rc = mg.main(['tree', str(self.root), '--static', '--verify'], run=fake)
        self.assertEqual((rc, err.getvalue().strip()), (0, ''))


class Page(Tree):
    """`html`: the hosts view as an interactive page. The page's behaviour is
    JS and is checked in a browser; these pin what Python hands it."""

    def setUp(self):
        super().setUp()
        self.write('host-config/alpha/dirsAsCategory.nix', SHIM)
        self.write('host-config/alpha/hw.nix', module('nixos'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'alpha', 'used', 'ghost'))
        self.write('hosts/home.nix', host('homeManager', 'sub'))

    def data(self):
        return mg.page_data(mg.select(self.g(), 'hosts'))

    def test_areas_hold_their_tree_and_know_their_place(self):
        self.write('users-config/u/dirsAsCategory.nix', SHIM)
        self.write('users-config/u/acct.nix', module('nixos'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'alpha', 'u', 'used', 'ghost'))
        d = self.data()
        areas = {a['title']: a for a in d['areas']}
        self.assertEqual({k: a['place'] for k, a in areas.items()},
                         {'host-config': 'behind', 'users-config': 'user',
                          'area': 'shared', 'not found': 'shared'})
        (used,) = areas['area']['children']
        self.assertEqual((used['id'], used['kind'], used['status']),
                         ('cat:area/used', 'category', 'imported'))
        self.assertEqual([c['id'] for c in used['children']], ['cat:area/used/sub'])

    def test_hosts_carry_their_hue_and_imports(self):
        d = self.data()
        hosts = {h['title']: h for h in d['hosts']}
        self.assertEqual(set(hosts), {'alpha-configuration', 'home'})
        self.assertEqual(hosts['alpha-configuration']['sub'], 'nixos')
        self.assertNotEqual(hosts['alpha-configuration']['hue'], hosts['home']['hue'])
        self.assertEqual(d['imports'][hosts['home']['id']], ['cat:area/used/sub'])

    def test_a_name_no_module_declares_gets_a_not_found_area(self):
        areas = {a['title']: a for a in self.data()['areas']}
        self.assertEqual([c['title'] for c in areas['not found']['children']], ['ghost'])

    def test_style_comes_from_the_python_palette(self):
        style = self.data()['style']
        self.assertEqual(style['palette']['category'], list(mg.PALETTE['category']))
        self.assertEqual((style['alert'], style['boxFill']), (list(mg.ALERT), mg.BOX_FILL))

    def test_page_fills_the_template_once(self):
        out = mg.page(mg.select(self.g(), 'hosts'))
        self.assertTrue(out.startswith('<!doctype html>'))
        self.assertNotIn(mg.PLACEHOLDER, out)
        self.assertIn('"title":"alpha-configuration"', out)

    def test_data_cannot_close_the_script_element(self):
        g = mg.Graph({'area:x': mg.Node('area:x', 'area', 'x'),
                      'cat:x/evil': mg.Node('cat:x/evil', 'category', '</script><b>'),
                      'agg:h:nixos': mg.Node('agg:h:nixos', 'aggregate', 'h', frozenset(['nixos']))},
                     [mg.Edge('area:x', 'cat:x/evil', 'contains'),
                      mg.Edge('agg:h:nixos', 'cat:x/evil', 'imports', 'nixos')], [])
        out = mg.page(g)
        script = out[out.index('const DATA'):]
        self.assertNotIn('</script><b>', script.split('\n')[0])
        self.assertIn('<\\/script><b>', out)
        self.assertEqual(out.count('</script>'), 1)          # only the template's own

    def test_a_template_without_one_placeholder_is_refused(self):
        bad = pathlib.Path(self._tmp.name) / 'template.html'
        bad.write_text('<!doctype html><script>const DATA = null;</script>')
        old, mg.TEMPLATE = mg.TEMPLATE, bad
        try:
            with self.assertRaises(SystemExit):
                mg.page(mg.select(self.g(), 'hosts'))
        finally:
            mg.TEMPLATE = old

    def test_cli_html(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = mg.main(['html', str(self.root), '--static'])
        self.assertEqual(rc, 0)
        self.assertIn('<title>Module graph</title>', out.getvalue())
        self.assertIn('"id":"cat:host-config/alpha"', out.getvalue())


HOME = '''{ config, ... }: {
    flake.modules.homeManager.homeAgg.imports =
        with config.flake.modules.homeManager; [ sub ];
}
'''


def turns_on(cls, *refs):
    """A module of class `cls` that refers to the given aggregates, the way
    enable-home-manager.nix refers to ellyHomeManager."""
    lines = ''.join(f'        x{k} = config.flake.modules.{r};\n' for k, r in enumerate(refs))
    return ('{ config, lib, ... }:\n    let moduleName = lib.removeSuffix ".nix" '
            '(baseNameOf __curPos.file);\n    in {\n'
            f'        flake.modules.{cls}.${{moduleName}} = {{ }};\n{lines}    }}\n')


class Enables(Tree):
    """A host does not import its Home Manager config: a module it imports
    refers to it. That reference is the `enables` edge."""

    def setUp(self):
        super().setUp()
        self.write('hosts/home.nix', HOME)
        self.write('hosts/alpha-configuration.nix', host('nixos', 'used'))

    def enabled(self):
        return {(e.src, e.dst, e.cls) for e in self.g().edges if e.kind == 'enables'}

    HOST, HOMEID = 'agg:hosts/alpha-configuration.nix:nixos', 'agg:hosts/home.nix:homeManager'

    def test_a_module_the_host_imports_refers_to_it(self):
        self.write('area/used/turn-on.nix', turns_on('nixos', 'homeManager.homeAgg'))
        self.assertEqual(self.enabled(), {(self.HOST, self.HOMEID, 'nixos')})

    def test_no_reference_no_edge(self):
        self.assertEqual(self.enabled(), set())

    def test_only_modules_of_the_hosts_class_count(self):
        # the darwin twin sits in the same category; a nixos host never gets it
        self.write('area/used/turn-on-darwin.nix', turns_on('darwin', 'homeManager.homeAgg'))
        self.assertEqual(self.enabled(), set())

    def test_a_module_imported_by_name_counts(self):
        self.write('area/never-whole/dirsAsCategory.nix', SHIM)
        self.write('area/never-whole/picked.nix', turns_on('nixos', 'homeManager.homeAgg'))
        self.write('hosts/alpha-configuration.nix', host('nixos', 'picked'))
        self.assertEqual(self.enabled(), {(self.HOST, self.HOMEID, 'nixos')})

    def test_a_reference_in_a_comment_does_not_count(self):
        self.write('area/used/turn-on.nix', turns_on('nixos') +
                   '# config.flake.modules.homeManager.homeAgg\n')
        self.assertEqual(self.enabled(), set())

    def test_page_splits_hosts_from_the_homes_they_enable(self):
        self.write('area/used/turn-on.nix', turns_on('nixos', 'homeManager.homeAgg'))
        d = mg.page_data(mg.select(self.g(), 'hosts'))
        self.assertEqual([h['title'] for h in d['hosts']], ['alpha-configuration'])
        self.assertEqual([h['title'] for h in d['homes']], ['home'])
        self.assertEqual(d['enables'][self.HOST], [self.HOMEID])
        self.assertEqual(d['enables'][self.HOMEID], [])

    def test_renderers_draw_it_dashed(self):
        self.write('area/used/turn-on.nix', turns_on('nixos', 'homeManager.homeAgg'))
        g = mg.select(self.g(), 'hosts')
        self.assertIn('-. enables .->', mg.mermaid(g))
        self.assertRegex(mg.dot(g), r'style=dashed penwidth=1.2 label="enables"')


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
        (area,) = [b for b in mg.boxes(g) if b.id == 'area:area']
        (used,) = area.subs
        self.assertEqual((used.id, used.items), ('cat:area/used', ['cat:area/used/sub']))

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
        self.assertIn('label=<<b>sub/</b><br/><font', out)    # HTML label
        self.assertIn('label=<<b>used/</b>  <font', out)     # a box's title
        self.assertNotIn('[style=dotted]', out)       # used -> sub is the box, not an arrow

    def test_cli_prints_mermaid(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = mg.main(['tree', str(self.root), '--categories-only', '--static'])
        self.assertEqual(rc, 0)
        self.assertIn('used/', buf.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=1)
