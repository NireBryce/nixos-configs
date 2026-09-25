#!/usr/bin/env python3
"""Fixture tests for cod-desc.py's --help parsers, plus shape checks on the
committed data and its wiring.

A wrong parse reads exactly like a correct one -- draft rows land in
cod-desc.tsv looking authoritative -- and the wiring checks are regex-
coupled to blesh.nix's and cod-desc.bash's exact shapes, so a rename or a
dropped import line fails here instead of silently disconnecting the
descriptions from the menu. Pure stdlib; runs in preflight and CI.

Covers:
  kingpin   (Go; sops, cod)   `--kms value, -k value  desc [$ENV]`,
                              COMMANDS block, `help, h` alias
  clap      (Rust; uv)        same-line descriptions with wrapped
                              continuations, <BRACKETED> placeholders,
                              repeat-marker dots (`--quiet...`), and the
                              long-help shape with the description on the
                              following line
  cod-desc.tsv                read_table strictness (3 fields, unique,
                              no trailing `=`), sort order, and the
                              committed file itself passing both
  wiring                      blesh.nix renders and imports cod-desc.bash,
                              sets NIRE_COD_DESC_TSV, and cod-desc.bash
                              advises __cod_complete_bash
"""
import importlib.util
import pathlib
import re
import unittest

HERE = pathlib.Path(__file__).resolve().parent
FLAKE = HERE.parent
DATA = FLAKE / 'modules/config-system/shell-config/bash/cod-desc.tsv'
BLESH = FLAKE / 'modules/config-system/shell-config/bash/blesh.nix'
ADVICE = FLAKE / 'modules/config-system/shell-config/bash/cod-desc.bash'

_spec = importlib.util.spec_from_file_location('cod_desc', HERE / 'cod-desc.py')
cod_desc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cod_desc)


KINGPIN_HELP = '''\
Usage:
  prog [flags] <command>

COMMANDS:
   completion  Generate shell completion scripts
   help, h     Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --decrypt, -d                            decrypt a file and output the result to stdout
   --kms value, -k value                    comma separated list of KMS ARNs [$SOPS_KMS_ARN]
   --shamir-secret-sharing-threshold value  the number of master keys required (default: 0)
   --verbose                                Enable verbose logging output
'''

CLAP_SAMELINE_HELP = '''\
An extremely fast Python package manager.

Usage: uv [OPTIONS] <COMMAND>

Commands:
  run        Run a command or script
  help       Display documentation for a command

Cache options:
  -n, --no-cache               Avoid reading from or writing to the cache, instead using a temporary
                               directory for the duration of the operation [env: UV_NO_CACHE=]
      --cache-dir <CACHE_DIR>  Path to the cache directory [env: UV_CACHE_DIR=]

Python options:
      --no-python-downloads  Disable automatic downloads of Python. [env:
                             "UV_PYTHON_DOWNLOADS=never"]
'''

CLAP_LONGHELP_HELP = '''\
Global options:
  -q, --quiet...
          Use quiet output
  -v, --verbose...
          Use verbose output
      --color <COLOR_CHOICE>
          Control the use of color in output [possible values: auto, always, never]
      --native-tls
          Whether to load TLS certificates from the platform's native
          certificate store

  -h, --help     Print help
  -V, --version  Print version
'''


class KingpinTest(unittest.TestCase):
    def test_flags_with_placeholders(self):
        found = cod_desc.parse_help(KINGPIN_HELP)
        self.assertEqual(found['--decrypt'],
                         'decrypt a file and output the result to stdout')
        # kingpin lists the long and short spellings on one line; both are
        # candidates cod serves, and both get the description
        self.assertEqual(found['-k'], found['--kms'])
        self.assertEqual(found['--kms'], 'comma separated list of KMS ARNs')

    def test_env_and_default_annotations_stripped(self):
        found = cod_desc.parse_help(KINGPIN_HELP)
        self.assertNotIn('$SOPS_KMS_ARN', found['--kms'])
        self.assertNotIn('(default: 0)', found['--shamir-secret-sharing-threshold'])
        self.assertIn('master keys', found['--shamir-secret-sharing-threshold'])

    def test_commands_block_with_alias(self):
        found = cod_desc.parse_help(KINGPIN_HELP)
        self.assertEqual(found['completion'], 'Generate shell completion scripts')
        # kingpin's "help, h" line: cod serves `help`, not the alias
        self.assertIn('help', found)
        self.assertNotIn('h', found)


class ClapSameLineTest(unittest.TestCase):
    def test_bracketed_placeholder_and_env(self):
        found = cod_desc.parse_help(CLAP_SAMELINE_HELP)
        self.assertEqual(found['--cache-dir'], 'Path to the cache directory')
        self.assertNotIn('UV_NO_CACHE', found['--no-cache'])
        self.assertTrue(found['--no-cache'].startswith('Avoid reading'))

    def test_wrapped_continuation_joined(self):
        found = cod_desc.parse_help(CLAP_SAMELINE_HELP)
        # the sentence wraps onto the next line, aligned to the description
        # column; the parse must rejoin it instead of dropping the tail
        self.assertIn('temporary directory', found['--no-cache'])
        # an [env: ...] annotation split across the wrap is cleaned too --
        # the joining happens before the annotation strip
        self.assertTrue(found['--no-python-downloads'].startswith(
            'Disable automatic downloads of Python.'))
        self.assertNotIn('never', found['--no-python-downloads'])

    def test_commands(self):
        found = cod_desc.parse_help(CLAP_SAMELINE_HELP)
        self.assertEqual(found['run'], 'Run a command or script')


class ClapLongHelpTest(unittest.TestCase):
    def test_description_on_following_line(self):
        found = cod_desc.parse_help(CLAP_LONGHELP_HELP)
        self.assertEqual(found['--quiet'], 'Use quiet output')
        self.assertEqual(found['-v'], 'Use verbose output')

    def test_repeat_marker_dots_not_in_candidate(self):
        found = cod_desc.parse_help(CLAP_LONGHELP_HELP)
        self.assertIn('--quiet', found)
        self.assertNotIn('--quiet...', found)

    def test_multiline_following_line_description(self):
        found = cod_desc.parse_help(CLAP_LONGHELP_HELP)
        self.assertIn('native', found['--native-tls'])
        self.assertIn('certificate store', found['--native-tls'])

    def test_possible_values_annotation_stripped(self):
        found = cod_desc.parse_help(CLAP_LONGHELP_HELP)
        self.assertEqual(found['--color'], 'Control the use of color in output')


class CommittedTableTest(unittest.TestCase):
    """The committed cod-desc.tsv itself -- what preflight is for."""

    def test_committed_file_passes_read_table(self):
        rows = cod_desc.read_table()
        self.assertTrue(rows)

    def test_committed_file_sorted(self):
        cod_desc.check_sorted()  # raises on drift

    def test_seed_commands_present(self):
        rows = cod_desc.read_table()
        for command in ('cod', 'sops', 'uv', 'tailscale'):
            self.assertIn(command, {c for c, _ in rows},
                          f'{command}: seed command missing from the table')

    def test_read_table_rejects_trailing_eq(self):
        import tempfile
        with tempfile.NamedTemporaryFile('w', suffix='.tsv',
                                         delete=False) as f:
            f.write('sops\t--value-stdin=\tdescription\n')
            path = f.name
        try:
            with self.assertRaises(ValueError, msg='trailing ='):
                cod_desc.read_table(pathlib.Path(path))
        finally:
            pathlib.Path(path).unlink()

    def test_read_table_rejects_wrong_field_count(self):
        import tempfile
        with tempfile.NamedTemporaryFile('w', suffix='.tsv',
                                         delete=False) as f:
            f.write('sops\t--decrypt\n')  # no description
            path = f.name
        try:
            with self.assertRaises(ValueError, msg='field count'):
                cod_desc.read_table(pathlib.Path(path))
        finally:
            pathlib.Path(path).unlink()

    def test_read_table_rejects_duplicate_key(self):
        import tempfile
        with tempfile.NamedTemporaryFile('w', suffix='.tsv',
                                         delete=False) as f:
            f.write('sops\t--decrypt\ta\nsops\t--decrypt\tb\n')
            path = f.name
        try:
            with self.assertRaises(ValueError, msg='duplicate'):
                cod_desc.read_table(pathlib.Path(path))
        finally:
            pathlib.Path(path).unlink()


class WiringTest(unittest.TestCase):
    """Regex-coupled to the declaring modules' exact shapes, like the
    keybinding-cheatsheet readers: a rename here should fail there."""

    def test_blesh_nix_renders_both_files(self):
        text = BLESH.read_text()
        self.assertIn('builtins.readFile ./cod-desc.tsv', text)
        self.assertIn('builtins.readFile ./cod-desc.bash', text)

    def test_blesh_nix_sets_and_exports_the_tsv_path(self):
        text = BLESH.read_text()
        # the variable the advice reads, and the store path it is given
        self.assertRegex(text, r'NIRE_COD_DESC_TSV=\$\{codDescTsv\}')
        self.assertRegex(text, r'ble-import -d \$\{codDescBash\}')

    def test_advice_advises_the_cod_completer(self):
        text = ADVICE.read_text()
        self.assertRegex(
            text, r'ble/function#advice after __cod_complete_bash ')
        # the guard that keeps non-cod sessions (the darwin hosts) silent
        self.assertIn('ble/is-function __cod_complete_bash', text)

    def test_advice_declares_a_global_assoc_cache(self):
        text = ADVICE.read_text()
        # regression: a plain array=() inside the function made every
        # lookup evaluate its subscript as arithmetic and silently miss
        self.assertIn('declare -A __nire_cod_desc=()', text)

    def test_blesh_nix_declares_cod_desc_variables(self):
        text = BLESH.read_text()
        for name in ('codDescTsv', 'codDescBash'):
            self.assertRegex(text, rf'(?m)^\s*{name} = pkgs.writeText')


if __name__ == '__main__':
    unittest.main()
