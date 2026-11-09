#!/usr/bin/env python3
"""Tests for how tailscale-acl.py reads its API token.

The token sits in secrets.yaml, whose recipient on the usual host is the SSH
host key, readable only by root. The script first tries sops as the invoking
user, and on failure falls back to `sudo sops` with an interactive prompt.
Each case replaces subprocess.run, so no sops, sudo or secret is touched.
Pure stdlib; runs in `just preflight`.
"""
import importlib.util
import os
import sys
import unittest
from types import SimpleNamespace
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(os.path.dirname(HERE), "tailscale-acl.py")
spec = importlib.util.spec_from_file_location("tailscale_acl", SCRIPT)
acl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(acl)

OK = SimpleNamespace(returncode=0, stdout="TOKEN\n", stderr="")
DENIED = SimpleNamespace(returncode=1, stdout="", stderr="no key matched")


def fake_run(calls, results):
    """A subprocess.run that records argv and answers from `results`."""
    queue = list(results)

    def run(argv, **kwargs):
        calls.append(list(argv))
        return queue.pop(0)

    return run


class GetToken(unittest.TestCase):
    def call(self, results, euid=1000, tty=True):
        calls = []
        with mock.patch.object(acl.subprocess, "run", fake_run(calls, results)), \
             mock.patch.object(acl.os, "geteuid", return_value=euid), \
             mock.patch.object(acl.sys.stdin, "isatty", return_value=tty):
            try:
                token = acl.get_token()
            except SystemExit as e:
                return calls, e
        return calls, token

    def test_user_key_works_without_sudo(self):
        calls, token = self.call([OK])
        self.assertEqual(token, "TOKEN")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("sudo", calls[0])

    def test_falls_back_to_sudo_when_user_cannot_decrypt(self):
        # plain sops fails; `sudo -v` (prompt, not captured); `sudo -n sops`
        calls, token = self.call([DENIED, SimpleNamespace(returncode=0), OK])
        self.assertEqual(token, "TOKEN")
        self.assertEqual(calls[1], ["sudo", "-v"])
        self.assertEqual(calls[2][:3], ["sudo", "-n", "sops"])

    def test_never_extracts_more_than_one_key(self):
        calls, _ = self.call([DENIED, SimpleNamespace(returncode=0), OK])
        for argv in (calls[0], calls[2]):
            self.assertIn("--extract", argv)
            self.assertIn('["tailscale_api_token"]', argv)

    def test_no_terminal_stops_without_calling_sudo(self):
        calls, result = self.call([DENIED], tty=False)
        self.assertIsInstance(result, SystemExit)
        self.assertIn("no terminal", str(result.code))
        self.assertEqual(len(calls), 1)

    def test_sudo_refused_stops(self):
        calls, result = self.call([DENIED, SimpleNamespace(returncode=1)])
        self.assertIsInstance(result, SystemExit)
        self.assertIn("sudo was not granted", str(result.code))
        self.assertEqual(len(calls), 2)

    def test_root_does_not_use_sudo(self):
        calls, result = self.call([DENIED], euid=0)
        self.assertIsInstance(result, SystemExit)
        self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
