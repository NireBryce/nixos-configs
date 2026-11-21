"""Tests for tools/docchecks/host_files.py.

factcheck is not importable where this runs, so the `factcheck`,
`factcheck.findings`, `factcheck.registry` and `tree` modules are stubbed
before the plugin is loaded by path. That exercises the plugin's own logic
(comment scanning, the directory and module-file rules), not the
registration or the roster reader, which factcheck's and nixtree's tests
cover.
"""
import importlib.util
import pathlib
import sys
import tempfile
import types
import unittest

REPO = pathlib.Path(__file__).resolve().parents[3]
PLUGIN = REPO / "tools" / "docchecks" / "host_files.py"
HOST_CONFIG = pathlib.Path("flake/modules/host-config")


class Finding:
    def __init__(self, category, path, message, sep="  "):
        self.category = category
        self.path = path
        self.message = message


def load_plugin():
    registered = {}

    def check(name, order):
        def decorate(function):
            registered[name] = function
            return function
        return decorate

    stubs = {
        "factcheck": types.ModuleType("factcheck"),
        "factcheck.findings": types.ModuleType("factcheck.findings"),
        "factcheck.registry": types.ModuleType("factcheck.registry"),
        "tree": types.ModuleType("tree"),
    }
    stubs["factcheck.findings"].Finding = Finding
    stubs["factcheck.registry"].check = check
    stubs["tree"].roster = lambda root: (["alpha"], {"alpha"})
    sys.modules.update(stubs)
    spec = importlib.util.spec_from_file_location("host_files_plugin", PLUGIN)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return registered["host_files"]


class Config:
    def section(self, name):
        return {}


class HostFilesCheckTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.run_check = staticmethod(load_plugin())

    def make_tree(self, comment):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = pathlib.Path(tmp.name)
        base = root / HOST_CONFIG
        (base / "alpha" / "hardware").mkdir(parents=True)
        (base / "alpha" / "hardware" / "hardware-alpha.nix").write_text("{}\n")
        (base / "alpha-configuration.nix").write_text(
            "{\n    includes.nixos = [\n"
            + "".join(f"        # {line}\n" for line in comment)
            + '        "alpha"\n    ];\n}\n')
        return root

    def findings(self, comment):
        return self.run_check(self.make_tree(comment), Config())

    def test_clean_fixture(self):
        self.assertEqual(self.findings([
            "host-config/alpha/hardware/: hardware-alpha.nix, nire-alpha, ts-alpha,",
            "elly@nire-alpha, durandal's hardware-beta.nix. See host-config/alpha.",
        ]), [])

    def test_missing_module_token(self):
        found = self.findings(["host-config/alpha/: hardware-alpha, foo-alpha"])
        self.assertEqual([item.category for item in found], ["UNKNOWN MODULE"])
        self.assertIn("foo-alpha", found[0].message)

    def test_missing_directory(self):
        found = self.findings(["host-config/alpha/vms/ holds the guests"])
        self.assertEqual([item.category for item in found], ["UNKNOWN DIR"])
        self.assertIn("host-config/alpha/vms", found[0].message)

    def test_prose_host_config_is_not_a_reference(self):
        self.assertEqual(self.findings(["sits under host-config/ rather than a category"]), [])


if __name__ == "__main__":
    unittest.main()
