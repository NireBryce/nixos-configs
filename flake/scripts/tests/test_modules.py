#!/usr/bin/env python3
"""Tests for modules.py's `drift` and orphan checks and its `add` scaffold.

Both read flake.moduleGraph; here a stand-in for `nix eval` answers with a
document built per test, so a check is shown firing on a tree broken on
purpose -- the real tree comes back clean, which proves nothing about
whether it could. Pure stdlib; runs via `just modules-test`, part of
`just preflight` and CI.
"""
import collections, contextlib, io, json, pathlib, subprocess, sys, tempfile, types, unittest

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
        self.root = pathlib.Path(self._tmp.name) / 'flake' / 'modules'   # the layout check_docs reads
        self.cats = {'used': 'area/used', 'sub': 'area/used/sub'}
        self.mods = {'a': 'area/used/a/a.nix', 'b': 'area/used/sub/b/b.nix', 'alpha': 'hosts/alpha.nix'}
        self.includes = {'alpha': {'nixos': ['used']}}
        self.enables = {}

    def tearDown(self):
        self._tmp.cleanup()

    def write_all(self):
        """Each module file as dirs-as-categories would read it: house style
        (what check_docs reads), with the same includes/enables the document
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


def tree_header():
    """The four-line header most modules in the real tree carry. The scaffold
    has to write that one: a header the tree has moved on from was left in
    the template once, and 227 of 241 modules disagreed with it."""
    headers = collections.Counter(
        tuple(p.read_text().splitlines()[:4])
        for p in (pathlib.Path(modules.__file__).resolve().parents[1] / 'modules').rglob('*.nix'))
    (header, _), = headers.most_common(1)
    return '\n'.join(header) + '\n'


TREE_HEADER = tree_header()


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
        self.assertTrue(text.startswith(TREE_HEADER), text)
        self.assertIn('homeManager = _: {', text)
        self.assertIn('# summary: does a thing', text)
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

    def test_reports_the_new_module_as_an_expected_orphan(self):
        doc = self.doc()
        doc['orphans'] = ['new-thing']          # what the graph says once the file exists
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.add(self.root, 'homeManager', 'area/used/new-thing/new-thing.nix', [], run=FakeNix(doc))
        self.assertEqual(rc, 0)
        self.assertIn('ORPHAN (expected -- brand new)', out.getvalue())

    def test_an_older_orphan_fails_the_scaffold(self):
        doc = self.doc()
        doc['orphans'] = ['new-thing', 'stale']
        self.assertEqual(self.add('homeManager', 'area/used/new-thing/new-thing.nix', doc=doc), 1)

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


class Main(Tree):
    def test_check_fails_on_drift_and_passes_when_the_readings_agree(self):
        self.assertEqual(quiet(modules.main, ['check', str(self.root)], run=FakeNix(self.doc())), 0)
        doc = self.doc()
        doc['categories']['ghost'] = {'dir': 'area/ghost'}       # evaluated, not in the files
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.main(['check', str(self.root)], run=FakeNix(doc))
        self.assertEqual(rc, 1)
        self.assertIn("DRIFT      category 'ghost'", out.getvalue())

    def test_orphans_is_not_a_subcommand_of_its_own(self):
        # it is a finding of `check`, from the graph `check` already evaluates
        self.assertEqual(quiet(modules.main, ['orphans', str(self.root)], run=FakeNix(self.doc())), 2)

    def test_check_fails_on_an_orphan_and_names_it(self):
        # The flake check module-orphans fails only when built, and `just
        # check` is --no-build, so this is the gate that has to fail (561).
        doc = self.doc()
        doc['orphans'] = ['lonely']
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.main(['check', str(self.root)], run=FakeNix(doc))
        self.assertEqual(rc, 1)
        self.assertIn("ORPHAN     'lonely'", out.getvalue())
        self.assertIn('see wiki/config-structure/module-files.md', out.getvalue())

    def test_check_passes_with_no_orphans_and_with_a_graph_that_has_no_field(self):
        doc = self.doc()
        doc['orphans'] = []
        self.assertEqual(quiet(modules.main, ['check', str(self.root)], run=FakeNix(doc)), 0)
        doc.pop('orphans')       # a graph from before the field existed
        self.assertEqual(quiet(modules.main, ['check', str(self.root)], run=FakeNix(doc)), 0)

    def test_check_fails_on_a_misplaced_class_part(self):
        doc = self.doc()
        doc['misplaced'] = ["module 'jq': `home` is set under `nixos`"]
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.main(['check', str(self.root)], run=FakeNix(doc))
        self.assertEqual(rc, 1)
        self.assertIn("MISPLACED  module 'jq'", out.getvalue())
        doc['misplaced'] = []
        self.assertEqual(quiet(modules.main, ['check', str(self.root)], run=FakeNix(doc)), 0)

    def test_an_orphan_and_drift_are_both_reported(self):
        doc = self.doc()
        doc['orphans'] = ['lonely']
        doc['categories']['ghost'] = {'dir': 'area/ghost'}
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = modules.main(['check', str(self.root)], run=FakeNix(doc))
        self.assertEqual(rc, 1)
        self.assertIn('ORPHAN', out.getvalue())
        self.assertIn('DRIFT', out.getvalue())


if __name__ == '__main__':
    unittest.main(verbosity=1)
