#!/usr/bin/env python3
"""Fixture tests for pinned-packages.py's module rewrites, plus shape checks
on the committed modules they rewrite.

The rewrites are regex-coupled to polytoken.nix's and zai-coding-helper.nix's
exact shapes. A reshaped module should fail here, not halfway through a bump
that has already downloaded four zips. Pure stdlib, no network, no nix; runs
in preflight and CI.
"""
import importlib.util
import json
import pathlib
import unittest

HERE = pathlib.Path(__file__).resolve().parent

_spec = importlib.util.spec_from_file_location('pinned_packages', HERE / 'pinned-packages.py')
pp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pp)

POLYTOKEN_FIXTURE = '''
                version = "0.8.13";
                platforms = {
                    x86_64-linux   = { urlPlatform = "linux-amd64"; hash = "sha256-old1"; };
                    aarch64-darwin = { urlPlatform = "macos-arm64"; hash = "sha256-old2"; };
                };
'''

ZAI_FIXTURE = '''
                    version = "0.1.0-beta.1";
                    src = pkgs.fetchurl {
                        url  = "https://registry.npmjs.org/x-${version}.tgz";
                        hash = "sha512-old";
                    };
                    npmDepsHash = "sha256-olddeps";
'''


class Rewrites(unittest.TestCase):
    def test_polytoken(self):
        out = pp.rewrite_polytoken(POLYTOKEN_FIXTURE, '0.9.0',
                                   {'linux-amd64': 'sha256-new1', 'macos-arm64': 'sha256-new2'})
        self.assertIn('version = "0.9.0";', out)
        self.assertIn('urlPlatform = "linux-amd64"; hash = "sha256-new1";', out)
        self.assertIn('urlPlatform = "macos-arm64"; hash = "sha256-new2";', out)
        self.assertNotIn('old', out)

    def test_polytoken_unknown_platform_fails(self):
        with self.assertRaises(SystemExit):
            pp.rewrite_polytoken(POLYTOKEN_FIXTURE, '0.9.0', {'linux-riscv64': 'sha256-x'})

    def test_zai(self):
        out = pp.rewrite_zai(ZAI_FIXTURE, '0.1.1', 'sha512-new', 'sha256-newdeps')
        self.assertIn('version = "0.1.1";', out)
        self.assertIn('hash = "sha512-new";', out)
        self.assertIn('npmDepsHash = "sha256-newdeps";', out)
        self.assertNotIn('old', out)

    def test_version_line_must_be_unique(self):
        with self.assertRaises(SystemExit):
            pp.set_version(POLYTOKEN_FIXTURE * 2, '1.0')

    def test_trimmed_package_json(self):
        pkg = {'name': 'x', 'dependencies': {'a': '1'}, 'devDependencies': {'b': '2'}}
        self.assertEqual(pp.trimmed_package_json(pkg), {'name': 'x', 'dependencies': {'a': '1'}})


class CommittedModules(unittest.TestCase):
    """The real files still have the shapes the rewrites expect."""

    def test_polytoken_module(self):
        text = pp.PINS['polytoken']['module'].read_text()
        plats = pp.polytoken_platforms(text)
        self.assertEqual(sorted(plats), ['linux-amd64', 'linux-arm64', 'macos-amd64', 'macos-arm64'])
        version = pp.pinned_version(text)
        # a no-op rewrite must round-trip -- proves every pattern matches exactly once
        hashes = dict(__import__('re').findall(r'urlPlatform\s*=\s*"([^"]+)";\s*hash\s*=\s*"([^"]+)"', text))
        self.assertEqual(pp.rewrite_polytoken(text, version, hashes), text)

    def test_zai_module(self):
        import re
        text = pp.PINS['zai-coding-helper']['module'].read_text()
        version = pp.pinned_version(text)
        src = re.search(r'^\s*hash\s*=\s*"([^"]+)"', text, re.M).group(1)
        deps = re.search(r'npmDepsHash\s*=\s*"([^"]+)"', text).group(1)
        self.assertEqual(pp.rewrite_zai(text, version, src, deps), text)

    def test_zai_files_agree(self):
        text = pp.PINS['zai-coding-helper']['module'].read_text()
        version = pp.pinned_version(text)
        pkg = json.loads(pp.ZAI_PACKAGE_JSON.read_text())
        lock = json.loads(pp.ZAI_LOCK.read_text())
        self.assertEqual(pkg['version'], version)
        self.assertEqual(lock['version'], version)
        self.assertNotIn('devDependencies', pkg)
        self.assertFalse([k for k, v in lock['packages'].items() if v.get('dev')],
                         'lockfile carries devDependencies -- see zai-coding-helper.nix')


if __name__ == '__main__':
    unittest.main()
