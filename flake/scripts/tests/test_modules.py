#!/usr/bin/env python3
"""Tests for modules.py's `orphans` check and its `add` scaffold.

Both read flake.moduleGraph; here a stand-in for `nix eval` answers with a
document built per test, so a check is shown firing on a tree broken on
purpose -- the real tree comes back clean, which proves nothing about
whether it could. Pure stdlib; runs via `just modules-test`, part of
`just preflight` and CI.
"""
import contextlib, io, json, pathlib, subprocess, sys, tempfile, types, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import modules  # noqa: E402


def quiet(fn, *args, **kw):
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
        return fn(*args, **kw)


class FakeNix:
    """Answers `nix eval --json path:<flake>#moduleGraph` with a document."""

    def __init__(self, doc):
        self.doc, self.calls = doc, []

    def __call__(self, cmd, **kw):
        self.calls.append(cmd)
        return types.SimpleNamespace(returncode=0, stdout=json.dumps(self.doc), stderr='')


def document(categories, modules, includes=None, enables=None):
    return {'version': 1, 'classes': ['nixos', 'homeManager', 'darwin'],
            'categories': {n: {'dir': d, 'members': [], 'nested': [], 'flag': None} for n, d in categories.items()},
            'modules': {n: {'path': p, 'classes': ['nixos']} for n, p in modules.items()},
            'includes': includes or {}, 'enables': enables or {}, 'folders': [], 'defaults': [], 'admin': []}


class Tree(unittest.TestCase):
    """A modules dir on disk (orphans reads files for ORPHAN-OK) and the
    document dirs-as-categories would publish for it."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name) / 'flake' / 'modules'   # the layout check_wiki reads
        self.cats = {'used': 'area/used', 'sub': 'area/used/sub'}
        self.mods = {'a': 'area/used/a/a.nix', 'b': 'area/used/sub/b/b.nix', 'alpha': 'hosts/alpha.nix'}
        self.includes = {'alpha': {'nixos': ['used']}}
        self.enables = {}

    def tearDown(self):
        self._tmp.cleanup()

    def write_all(self):
        """Each module file as dirs-as-categories would read it: house style
        (what check_wiki reads), with the same includes/enables the document
        gets. A file a test wrote itself (ORPHAN-OK) is left alone."""
        for name, p in self.mods.items():
            f = self.root / p
            if f.exists() and 'ORPHAN-OK' in f.read_text():
                continue
            f.parent.mkdir(parents=True, exist_ok=True)
            lines = [f'    {kind}.{cls} = [ {" ".join(chr(34) + n + chr(34) for n in names)} ];'
                     for kind, table in (('includes', self.includes), ('enables', self.enables))
                     for cls, names in table.get(name, {}).items()]
            f.write_text('{\n' + '\n'.join(lines + ['    nixos = { };']) + '\n}\n')

    def doc(self):
        self.write_all()
        return document(self.cats, self.mods, self.includes, self.enables)


class Orphans(Tree):
    def found(self):
        return {name for name, _, _ in quiet(modules.orphans, self.root, self.doc())}

    def test_clean_tree_has_no_findings(self):
        self.assertEqual(self.found(), set())

    def test_a_category_nothing_reaches_is_reported(self):
        self.cats['lonely'] = 'area/lonely'
        self.mods['l'] = 'area/lonely/l/l.nix'
        self.assertEqual(self.found(), {'l'})

    def test_a_nested_category_is_reached_through_its_parent(self):
        self.assertNotIn('b', self.found())

    def test_a_module_named_in_includes_or_enables_is_reached(self):
        self.cats['lonely'] = 'area/lonely'
        self.mods['picked'] = 'area/lonely/picked.nix'
        self.mods['other'] = 'area/lonely/other.nix'
        self.mods['turned-on'] = 'area/lonely/turned-on.nix'
        self.includes['alpha']['nixos'].append('picked')
        self.enables['a'] = {'homeManager': ['turned-on']}
        self.assertEqual(self.found(), {'other'})

    def test_a_module_including_another_reaches_it(self):
        # kde-desktop includes kde-base: kde-base is reached that way
        self.cats['desk'] = 'area/desk'
        self.mods['full'] = 'area/desk/full.nix'
        self.mods['base'] = 'area/desk/base.nix'
        self.includes['alpha']['nixos'].append('full')
        self.includes['full'] = {'nixos': ['base']}
        self.assertEqual(self.found(), set())

    def test_entry_points_outside_categories_are_not_orphans(self):
        self.mods['beta'] = 'hosts/beta.nix'
        self.assertEqual(self.found(), set())

    def test_orphan_ok_in_the_file_is_respected(self):
        self.cats['lonely'] = 'area/lonely'
        self.mods['kept'] = 'area/lonely/kept.nix'
        f = self.root / 'area/lonely/kept.nix'
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text('# ORPHAN-OK: for a host not configured now\n{ nixos = { }; }\n')
        self.assertEqual(self.found(), set())


class Graph(Tree):
    def test_reads_a_path_ref_beside_the_modules_dir(self):
        fake = FakeNix(self.doc())
        modules.graph(self.root, fake)
        self.assertEqual(fake.calls[0][:3], ['nix', 'eval', '--json'])
        self.assertEqual(fake.calls[0][3], f'path:{self.root.resolve().parent}#moduleGraph')

    def test_a_failed_evaluation_says_why(self):
        bad = lambda cmd, **kw: types.SimpleNamespace(returncode=1, stdout='', stderr='error: boom\n')
        with self.assertRaises(SystemExit) as cm:
            modules.graph(self.root, bad)
        self.assertIn('boom', str(cm.exception))


class Add(Tree):
    """`add` writes into a real git repo: it `git add`s what it creates."""

    def setUp(self):
        super().setUp()
        self.write_all()
        subprocess.run(['git', 'init', '-q', str(self._tmp.name)], check=True)
        subprocess.run(['git', '-C', self._tmp.name, 'add', '-A'], check=True)

    def add(self, cls, target, *desc, doc=None):
        return quiet(modules.add, self.root, cls, target, list(desc), run=FakeNix(doc or self.doc()))

    def test_scaffolds_the_new_shape_and_stages_it(self):
        self.assertEqual(self.add('homeManager', 'area/used/new-thing/new-thing.nix', 'does', 'a', 'thing'), 0)
        text = (self.root / 'area/used/new-thing/new-thing.nix').read_text()
        self.assertTrue(text.startswith('# Module file:'))
        self.assertIn('homeManager = _: {', text)
        self.assertIn('# # description = "does a thing";', text)
        self.assertNotIn('moduleName', text)
        staged = subprocess.run(['git', '-C', self._tmp.name, 'diff', '--cached', '--name-only'],
                                capture_output=True, text=True).stdout
        self.assertIn('flake/modules/area/used/new-thing/new-thing.nix', staged)

    def test_refuses_what_dirs_as_categories_would(self):
        cases = [('flake', 'area/used/x.nix'),           # not a class it knows
                 ('nixos', 'loose.nix'),                 # not inside a folder
                 ('nixos', 'hosts/gamma.nix'),           # outside every category
                 ('nixos', 'area/used/q/a.nix'),         # name taken by a module
                 ('nixos', 'area/used/q/sub.nix'),       # name taken by a category
                 ('nixos', 'area/used/q/default.nix'),   # default.nix means something else
                 ('nixos', '../escape.nix')]
        for cls, target in cases:
            self.assertEqual(self.add(cls, target), 1, target)
            self.assertFalse((self.root / target).exists(), target)

    def test_refuses_a_description_that_breaks_the_string(self):
        self.assertEqual(self.add('nixos', 'area/used/q/q.nix', 'a', '"quote'), 1)


class Drift(Tree):
    """The file-only reading against the evaluated graph."""

    def test_agreement_is_clean_and_each_kind_of_disagreement_reported(self):
        doc = self.doc()
        self.assertEqual(quiet(modules.drift, doc, json.loads(json.dumps(doc))), [])
        static = json.loads(json.dumps(doc))
        static['categories']['extra'] = {'dir': 'area/extra'}           # a folder read as a category
        static['modules']['a']['classes'] = ['homeManager']              # a class read wrong
        static['includes']['alpha']['nixos'] = ['used', 'more']          # an include list read wrong
        static['enables']['a'] = {'homeManager': ['x']}                  # an enables only the files show
        hits = quiet(modules.drift, doc, static)
        self.assertEqual(len(hits), 4, hits)
        for needle in ("category 'extra'", "module 'a'", "includes 'alpha'", "enables 'a'"):
            self.assertTrue(any(needle in h for h in hits), needle)


class GraphFile(Tree):
    def test_graph_from_a_file_needs_no_nix(self):
        self.cats['lonely'] = 'area/lonely'
        self.mods['l'] = 'area/lonely/l/l.nix'
        f = pathlib.Path(self._tmp.name) / 'graph.json'
        f.write_text(json.dumps(self.doc()))
        no_nix = lambda *a, **kw: (_ for _ in ()).throw(AssertionError('nix was called'))
        self.assertEqual(quiet(modules.main, ['orphans', str(self.root), '--graph', str(f)], run=no_nix), 1)


class Main(Tree):
    def test_check_fails_on_a_finding(self):
        self.cats['lonely'] = 'area/lonely'
        self.mods['l'] = 'area/lonely/l/l.nix'
        doc = self.doc()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.main(['check', str(self.root)], run=FakeNix(doc))
        self.assertEqual(rc, 1)
        self.assertIn("ORPHAN     'l'", out.getvalue())
        self.assertNotIn('DRIFT', out.getvalue())          # the tree reads the same both ways
        self.cats.pop('lonely'); self.mods.pop('l')
        self.assertEqual(quiet(modules.main, ['orphans', str(self.root)], run=FakeNix(self.doc())), 0)


if __name__ == '__main__':
    unittest.main(verbosity=1)
