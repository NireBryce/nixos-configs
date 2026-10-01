#!/usr/bin/env python3
"""Fixture tests for wiki_gen.py, the generator behind `just wiki-gen`.

Against the real tree a clean `--check` proves only that today's tables
match today's sources, not that a changed source would be noticed or that a
hand-written cell survives a rewrite. So this builds a small repo in a temp
directory (hosts.nix, host configs, category shims, wiki pages carrying the
regions), changes a source fact on purpose, and asserts what `--check`
reports and what a write run produces. Pure stdlib; runs via
`just wiki-gen-test`, part of `just preflight` and so of CI.
"""
import contextlib, io, pathlib, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import wiki_gen  # noqa: E402

SHIM = 'import (findModulesRoot (dirOf shimFile) + "/_lib/category-collector.nix") { }\n'
HOSTS_NIX = '''{
    flake.nixosConfigurations = {
        nire-alpha = mkHost "x86_64-linux" config.flake.modules.nixos.alphaConfiguration;
        nire-beta  = mkHost "x86_64-linux" config.flake.modules.nixos.betaConfiguration;
        guest      = mkHost "x86_64-linux" config.flake.modules.nixos.guestConfiguration;
    };
    flake.darwinConfigurations = {
        nire-gamma = mkDarwinHost "aarch64-darwin" config.flake.modules.darwin.gammaConfiguration;
    };
}
'''
MOD = '''{ lib, ... }:
let moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in { flake.modules.CLASS.${moduleName} = with pkgs; [ ]; }
'''
HOSTS_MD = '''# Hosts

<!-- generated:hosts-table -->

| Host | Class | Role | Wipes `/root`? | Tailnet name |
|---|---|---|---|---|
| `nire-alpha` | nixos | workstation | yes | `ts-alpha` |
| `nire-beta` | nixos | server | yes | `ts-beta` |
| `nire-gamma` | darwin | laptop | n/a | `ts-gamma` |

<!-- /generated -->

Prose after the table.
'''
INDEX_MD = '''# Categories

<!-- generated:categories-index-system -->
<!-- /generated -->

Between the tables.

<!-- generated:categories-index-homelab -->
<!-- /generated -->
'''
COUNTS_MD = '''# Counts

<!-- generated:module-counts -->
<!-- /generated -->
'''


def quiet(fn, *a, **kw):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*a, **kw)


class Fixture(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)
        m = 'flake/modules/'
        self.write(m + '_lib/category-collector.nix', '# collector\n')
        self.write(m + 'host-config/hosts.nix', HOSTS_NIX)
        self.write(m + 'host-config/alpha-configuration.nix',
                   'with config.flake.modules.nixos; [ impermanence homelab ]\n')
        self.write(m + 'host-config/beta-configuration.nix',
                   'with config.flake.modules.nixos; [ boot ]\n')
        self.write(m + 'host-config/gamma-configuration.nix',
                   'with config.flake.modules.darwin; [ boot ]\n')
        g = m + 'general-config/'
        for cat, cls in [('boot', 'darwin'), ('impermanence', 'nixos'),
                         ('homelab', 'nixos'), ('homelab/backup', 'nixos'),
                         ('impermanence/rollback', 'homeManager')]:
            self.write(g + cat + '/dirsAsCategory.nix', SHIM)
            self.write(g + cat + '/thing.nix', MOD.replace('CLASS', cls))
        self.write(g + 'boot/other.nix', MOD.replace('CLASS', 'nixos'))
        for page in ('boot', 'impermanence', 'homelab', 'backup'):
            self.write(f'wiki/categories/{page}.md', f'# {page}\n')
        self.write('wiki/hosts.md', HOSTS_MD)
        self.write('wiki/categories/00-INDEX.md', INDEX_MD)
        self.write('wiki/module-style-guide-for-agents.md', COUNTS_MD)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def read(self, rel):
        return (self.root / rel).read_text()

    def gen(self):
        return quiet(wiki_gen.run, self.root, True)

    def check(self):
        return quiet(wiki_gen.run, self.root, False)[0]

    def fill_hand_cells(self):
        p = self.root / 'wiki/categories/00-INDEX.md'
        p.write_text(p.read_text().replace(' |  |', ' | some hosts |'))


class Hosts(Fixture):
    def test_renders_from_hosts_nix(self):
        self.gen()
        text = self.read('wiki/hosts.md')
        self.assertIn('| `nire-alpha` | nixos | workstation | yes | `ts-alpha` |', text)
        # beta imports no impermanence: derived, and bold as the exception
        self.assertIn('| `nire-beta` | nixos | server | **no** | `ts-beta` |', text)
        self.assertIn('| `nire-gamma` | darwin | laptop | n/a | `ts-gamma` |', text)
        self.assertNotIn('guest', text)  # no nire- prefix, not a fleet host
        self.assertTrue(text.endswith('<!-- /generated -->\n\nProse after the table.\n'))

    def test_idempotent(self):
        self.gen()
        before = {p: p.read_text() for p in (self.root / 'wiki').rglob('*.md')}
        _, notes = self.gen()
        self.assertEqual(notes, [])
        self.assertEqual(before, {p: p.read_text() for p in before})

    def test_source_change_is_stale_until_regenerated(self):
        self.gen()
        self.fill_hand_cells()
        self.assertEqual(self.check(), [])
        p = self.root / 'flake/modules/host-config/hosts.nix'
        p.write_text(p.read_text().replace('nire-beta  = mkHost', 'nire-beta  = mkDarwinHost'))
        findings = self.check()
        self.assertEqual(len(findings), 1)
        self.assertTrue(findings[0].startswith("STALE GENERATED  wiki/hosts.md: region 'hosts-table'"))
        self.assertIn('just wiki-gen', findings[0])
        self.gen()
        self.assertIn('| `nire-beta` | darwin | server | n/a | `ts-beta` |', self.read('wiki/hosts.md'))
        self.assertEqual(self.check(), [])

    def test_hand_edit_to_derived_cell_is_reverted_role_kept(self):
        self.gen()
        self.fill_hand_cells()
        p = self.root / 'wiki/hosts.md'
        p.write_text(p.read_text().replace('workstation | yes', 'big desk | no'))
        self.assertTrue(any(f.startswith('STALE GENERATED') for f in self.check()))
        self.gen()
        self.assertIn('| `nire-alpha` | nixos | big desk | yes |', self.read('wiki/hosts.md'))

    def test_new_host_gets_empty_role_finding(self):
        self.gen()
        self.fill_hand_cells()
        self.write('flake/modules/host-config/delta-configuration.nix',
                   'with config.flake.modules.nixos; [ ]\n')
        p = self.root / 'flake/modules/host-config/hosts.nix'
        p.write_text(p.read_text().replace(
            '        guest', '        nire-delta = mkHost "x86_64-linux" x;\n        guest'))
        findings, _ = self.gen()
        self.assertEqual(findings, [
            "EMPTY HAND CELL  wiki/hosts.md: region 'hosts-table' row "
            "'nire-delta' has no Role -- it is hand-written; fill it in (the "
            "generated columns come from flake/modules/host-config/hosts.nix "
            "and each host's import list)"])
        self.assertIn('| `nire-delta` | nixos |  | **no** | `ts-delta` |', self.read('wiki/hosts.md'))

    def test_removed_host_reports_dropped_hand_text(self):
        self.gen()
        p = self.root / 'flake/modules/host-config/hosts.nix'
        p.write_text(p.read_text().replace(
            '        nire-beta  = mkHost "x86_64-linux" config.flake.modules.nixos.betaConfiguration;\n', ''))
        _, notes = self.gen()
        self.assertTrue(any("'`nire-beta`'" in n and "'Role': 'server'" in n for n in notes), notes)
        self.assertNotIn('nire-beta', self.read('wiki/hosts.md'))

    def test_missing_host_config_is_an_error_not_a_guess(self):
        (self.root / 'flake/modules/host-config/beta-configuration.nix').unlink()
        findings = self.check()
        self.assertTrue(any(f.startswith("GEN ERROR  wiki/hosts.md: region 'hosts-table'")
                            and 'beta-configuration.nix' in f for f in findings), findings)


class Categories(Fixture):
    def test_split_nested_classes_and_pageless(self):
        self.gen()
        text = self.read('wiki/categories/00-INDEX.md')
        system, homelab = text.split('Between the tables.')
        self.assertIn('| [boot](boot.md) | `general-config/boot/` | nixos, darwin |  |', system)
        self.assertIn('| [impermanence](impermanence.md) | `general-config/impermanence/` '
                      '(+ nested `rollback`) | nixos, homeManager |  |', system)
        self.assertNotIn('rollback](', system)  # no page, no row
        self.assertNotIn('homelab', system)
        self.assertIn('| [backup](backup.md) | `general-config/homelab/backup/` | nixos |', homelab)
        self.assertIn('| [homelab](homelab.md) | `general-config/homelab/` (+ nested `backup`) |', homelab)
        self.assertLess(homelab.index('[backup]'), homelab.index('[homelab]'))

    def test_imported_by_survives_and_dir_page_links(self):
        self.gen()
        self.fill_hand_cells()
        self.write('wiki/categories/homelab/00-INDEX.md', '# homelab\n')
        (self.root / 'wiki/categories/homelab.md').unlink()
        self.assertTrue(any('categories-index-homelab' in f for f in self.check()))
        self.gen()
        self.assertIn('| [homelab](homelab/00-INDEX.md) | `general-config/homelab/` '
                      '(+ nested `backup`) | nixos | some hosts |',
                      self.read('wiki/categories/00-INDEX.md'))


class Counts(Fixture):
    def test_counts(self):
        self.gen()
        text = self.read('wiki/module-style-guide-for-agents.md')
        n_nix = len(list((self.root / 'flake/modules').rglob('*.nix')))
        self.assertIn(f'| total `.nix` files under `flake/modules/` | {n_nix} |', text)
        self.assertIn('| module header (`moduleName = lib.removeSuffix ...`) | 6 |', text)
        self.assertIn('| `# # description` as first body line | 0 |', text)
        self.assertIn('| `with pkgs;` package lists | 6 |', text)


class Markers(Fixture):
    def test_unknown_missing_broken(self):
        self.gen()
        self.fill_hand_cells()
        p = self.root / 'wiki/module-style-guide-for-agents.md'
        p.write_text('# Counts\n\n<!-- generated:no-such -->\n<!-- /generated -->\n')
        self.write('wiki/other.md', '# x\n\n<!-- generated:hosts-table -->\n| a |\n')
        findings = self.check()
        kinds = sorted(f.split('  ')[0] for f in findings)
        self.assertEqual(kinds, ['BROKEN REGION', 'MISSING REGION', 'UNKNOWN REGION'], findings)

    def test_markers_in_code_are_not_regions(self):
        self.gen()
        self.fill_hand_cells()
        self.write('wiki/style.md', '# s\n\nInline `<!-- /generated -->` and:\n\n```\n'
                   '<!-- generated:hosts-table -->\n| x |\n<!-- /generated -->\n```\n')
        self.assertEqual(self.check(), [])

    def test_sibling_may_carry_same_region(self):
        self.gen()
        self.fill_hand_cells()
        self.write('wiki/hosts-for-agents.md',
                   '# Hosts, for agents\n\n<!-- generated:hosts-table -->\n<!-- /generated -->\n')
        findings, _ = self.gen()
        # The copy starts without hand cells, so each row asks for its Role.
        self.assertEqual(len(findings), 3)
        self.assertTrue(all(f.startswith('EMPTY HAND CELL  wiki/hosts-for-agents.md') for f in findings))


if __name__ == '__main__':
    unittest.main()
