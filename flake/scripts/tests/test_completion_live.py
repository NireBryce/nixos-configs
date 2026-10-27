#!/usr/bin/env python3
"""Live Tab-completion checks for the ble.sh description advice and the
carapace read-fix, driven through a real pty with terminal-puppeteer.

Why this exists: the three bugs found in these files on 2026-10-26 (the
read-fix's swapped split, carapace-desc.bash's dead ADVICE_EXIT guard,
cod-desc.bash's function-local table) all passed checks that stubbed
ble.sh's functions, and all showed up in seconds with a real Tab press in
an attached ble.sh. This is that Tab press, scripted.

Not part of `just preflight`: it needs an installed ble.sh, cod (with its
per-user daemon), carapace and terminal-puppeteer, and takes ~30s. Run it
with `just completion-live-test`, e.g. after a switch or when editing
carapace-desc.bash, cod-desc.bash, cod-desc.tsv or the read-fix. Each
missing prerequisite skips with the command that fixes it.

What it builds: a throwaway rc that wires the files in the order bash.nix
does (cod init, carapace, read-fix, then the advice), using the files in
this working tree, in an otherwise empty HOME. Differences from the real
shell, deliberately: the advice files are loaded with `ble-import` right
away instead of `ble-import -d` (the deferred load only fires from ble.sh's
idle loop, which a test cannot wait on without a blocking command that
stops it), and fzf-menu is not loaded, so the menu is ble.sh's own `desc`
menu. Both are still loaded by `ble-import`, which sources inside a
function -- the property the cod table bug depended on.

cod's daemon is per-user and ignores HOME, so the cod case needs `sops`
already learned (`cod learn -- sops --help`); it is skipped otherwise.

COMPLETION_LIVE_DIR points the run at another directory holding
carapace-desc.bash, cod-desc.bash, cod-desc.tsv and
carapace-completer-read-fix.bash (e.g. copies of an older generation),
which is how a test like this is shown to fail on the old code.
TERMINAL_PUPPETEER is the path to terminal-puppeteer.py when it is not on
PATH as `terminal-puppeteer`.
"""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

FLAKE = pathlib.Path(__file__).resolve().parents[2]
BASH_DIR = FLAKE / 'modules/general-config/shell-config/bash'
FILES = pathlib.Path(os.environ.get('COMPLETION_LIVE_DIR') or BASH_DIR)


def _puppeteer():
    path = os.environ.get('TERMINAL_PUPPETEER')
    if path:
        return ['python3', path] if pathlib.Path(path).is_file() else None
    found = shutil.which('terminal-puppeteer')
    return [found] if found else None


def _ble_sh():
    helper = shutil.which('blesh-share')
    if not helper:
        return None
    share = subprocess.run([helper], capture_output=True, text=True,
                           check=False).stdout.strip()
    path = pathlib.Path(share) / 'ble.sh'
    return path if path.is_file() else None


def _cod_knows(command):
    if not shutil.which('cod'):
        return False
    out = subprocess.run(['cod', 'list'], capture_output=True, text=True,
                         check=False).stdout
    return any(line.split()[1:2] and
               pathlib.Path(line.split()[1]).name == command
               for line in out.splitlines())


class LiveCompletionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.puppeteer = _puppeteer()
        if not cls.puppeteer:
            raise unittest.SkipTest(
                'terminal-puppeteer not found: put it on PATH as '
                '`terminal-puppeteer` or set TERMINAL_PUPPETEER=<path to '
                'terminal-puppeteer.py>')
        cls.ble = _ble_sh()
        if not cls.ble:
            raise unittest.SkipTest('ble.sh not found (blesh-share)')
        for tool in ('cod', 'carapace', 'jq'):
            if not shutil.which(tool):
                raise unittest.SkipTest(f'{tool} not on PATH')
        for name in ('carapace-desc.bash', 'cod-desc.bash', 'cod-desc.tsv',
                     'carapace-completer-read-fix.bash'):
            if not (FILES / name).is_file():
                raise unittest.SkipTest(f'{FILES / name} missing')
        cls.tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.tmp.cleanup)
        tmp = pathlib.Path(cls.tmp.name)
        (tmp / 'home').mkdir()
        # ble.sh keeps its cache under $XDG_CACHE_HOME (or ~/.cache) only if
        # that directory already exists; otherwise it falls back to a path
        # inside its read-only store directory and refuses to load.
        (tmp / 'cache').mkdir()
        cls.rc = tmp / 'bashrc'
        cls.rc.write_text(f"""PS1='$ '
source {cls.ble} --attach=none
source <(cod init $$ bash)
source <(carapace _carapace bash)
source {FILES / 'carapace-completer-read-fix.bash'}
bleopt complete_menu_style=desc
NIRE_COD_DESC_TSV={FILES / 'cod-desc.tsv'}
ble-import {FILES / 'carapace-desc.bash'}
ble-import {FILES / 'cod-desc.bash'}
ble-attach
""")
        cls.home = tmp / 'home'

    def drive(self, *steps):
        """Run steps in the throwaway shell; return (exit code, output).

        WAIT-FOR matches the whole transcript, echo of the typed line
        included, so every pattern here is text the typed input cannot
        contain (the `READY-42-1` marker is computed by the shell and only
        reads `-1` once ble.sh has attached, so a shell where ble.sh failed
        to load fails here, not in a completion step; the menu rows exist
        only once drawn)."""
        env = {'HOME': str(self.home), 'USER': 'test', 'LANG': 'C.UTF-8',
               'TERM': 'xterm', 'PATH': os.environ['PATH'],
               'XDG_CACHE_HOME': str(self.home.parent / 'cache')}
        cmd = [*self.puppeteer, '--cmd', f'bash --rcfile {self.rc} -i',
               '--connect-wait', '6', '--wait-for-timeout', '15',
               'echo READY-$((20+22))-${BLE_ATTACHED-none}', 'ENTER',
               'WAIT-FOR:READY-42-1', *steps]
        run = subprocess.run(cmd, env=env, capture_output=True, text=True,
                             check=False, timeout=120)
        return run.returncode, run.stdout + run.stderr

    def assertCompletes(self, steps):
        code, out = self.drive(*steps)
        self.assertEqual(code, 0, out)
        # the shell's own complaints show up in the transcript
        for bad in ('arithmetic syntax error', 'not a valid identifier'):
            self.assertNotIn(bad, out)

    def test_carapace_completion_survives_the_read_fix(self):
        # the read-fix once swapped the flag and the candidates, so every
        # carapace completion came back empty
        self.assertCompletes(
            ['git commit --am', 'TAB', 'WAIT-FOR:amend', 'CTRL-C'])

    def test_carapace_menu_shows_descriptions(self):
        # carapace-desc.bash once bailed on carapace's exit status 1
        self.assertCompletes(
            ['git commit --a', 'TAB', 'TAB',
             r'WAIT-FOR:/--amend\s+: amend previous commit/', 'CTRL-C'])

    def test_cod_menu_shows_descriptions(self):
        # cod-desc.bash once built its table in a function-local variable
        if not _cod_knows('sops'):
            self.skipTest('cod has not learned sops: '
                          'cod learn -- sops --help')
        self.assertCompletes(
            ['sops --va', 'TAB', 'TAB',
             r'WAIT-FOR:/--value-stdin\s+: read the value for `set` from '
             r'stdin/', 'CTRL-C'])


if __name__ == '__main__':
    unittest.main()
