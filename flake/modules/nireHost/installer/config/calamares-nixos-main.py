#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Replaces calamares-nixos-extensions' own modules/nixos/main.py (nixpkgs
# pkgs/by-name/ca/calamares-nixos-extensions/src/modules/nixos/main.py) --
# copied into $out by installer-calamares.nix's overrideAttrs postInstall,
# over the file this same package would otherwise have shipped.
#
# The original run() builds a template-substituted configuration.nix from
# Calamares wizard answers (locale/keyboard/hostname/user/package choices)
# and hardware-configuration.nix from nixos-generate-config, then runs a
# plain, non-flake `nixos-install`. This version skips all of that and runs
# `nixos-install --flake` against nire-testbed's own flake config instead,
# which nire-installer already carries embedded and real (see
# installer-configuration.nix's environment.etc."nixos-configs", and
# hardware-testbed.nix, which has real fileSystems/boot.initrd values for
# this exact disk as of 2026-08-16 -- a freshly generated
# hardware-configuration.nix would only need throwing away).
#
# Kept verbatim from the original: the imports actually still used,
# env_is_set/generateProxyStrings/pretty_name/pretty_status_message (calamares
# polls pretty_status_message() for the UI's status text), and the whole
# NixProgress class plus the _ACT_*/_RES_PROGRESS constants above it --
# self-contained, only consumes `nixos-install --log-format internal-json`
# stdout, has no dependency on anything deleted below. Dropped entirely:
# every cfg*/@@variable@@ template string, catenate(), fix_btrfs_subvolumes(),
# the nixos-generate-config invocation and hardware-configuration.nix
# read-fix-write dance, and every gs.value() read that only fed those --
# none of it is relevant once nixos-install --flake is doing the work.
# configparser/re imports dropped with them.
import json
import libcalamares
import os
import subprocess

import gettext

_ = gettext.translation(
    "calamares-python",
    localedir=libcalamares.utils.gettext_path(),
    languages=libcalamares.utils.gettext_languages(),
    fallback=True,
).gettext


def env_is_set(name):
    envValue = os.environ.get(name)
    return not (envValue is None or envValue == "")

def generateProxyStrings():
    proxyEnv = []
    if env_is_set('http_proxy'):
        proxyEnv.append('http_proxy={}'.format(os.environ.get('http_proxy')))
    if env_is_set('https_proxy'):
        proxyEnv.append('https_proxy={}'.format(os.environ.get('https_proxy')))
    if env_is_set('HTTP_PROXY'):
        proxyEnv.append('HTTP_PROXY={}'.format(os.environ.get('HTTP_PROXY')))
    if env_is_set('HTTPS_PROXY'):
        proxyEnv.append('HTTPS_PROXY={}'.format(os.environ.get('HTTPS_PROXY')))

    if len(proxyEnv) > 0:
        proxyEnv.insert(0, "env")

    return proxyEnv

def pretty_name():
    return _("Installing NixOS.")


status = pretty_name()


def pretty_status_message():
    return status


# nix internal-json activity/result types
_ACT_COPY_PATH = 100
_ACT_COPY_PATHS = 103
_ACT_BUILDS = 104
_RES_PROGRESS = 105


class NixProgress:
    """Parse nix internal-json output and track build/copy progress."""

    def __init__(self):
        self._builds_done = 0
        self._builds_expected = 0
        self._copies_done = 0
        self._copies_expected = 0
        self._per_act_progress = {}
        self._copy_bytes = {}
        self._activities = {}
        self.fraction = 0.0
        self._floor = 0.0
        self._floor_done = 0
        self.log_messages = []

    def handle(self, line):
        """Process one line. Returns True for @nix lines, False for plain text."""
        line = line.strip()
        if not line:
            return True
        if not line.startswith("@nix "):
            return False
        try:
            msg = json.loads(line[5:])
        except (json.JSONDecodeError, ValueError):
            return False

        action = msg.get("action")
        if action == "start":
            self._on_start(msg)
        elif action == "stop":
            self._on_stop(msg)
        elif action == "result":
            self._on_result(msg)
        elif action == "msg":
            level = msg.get("level", 0)
            text = msg.get("msg", "")
            if level <= 1 and text:
                self.log_messages.append(text)

        self._update()
        return True

    def _on_start(self, msg):
        act_id = msg["id"]
        act_type = msg.get("type", 0)
        self._activities[act_id] = act_type
        text = msg.get("text", "")
        if text and msg.get("level", 5) <= 3:
            self.log_messages.append(text)

    def _on_stop(self, msg):
        act_id = msg["id"]
        self._activities.pop(act_id, None)
        self._copy_bytes.pop(act_id, None)

    def _on_result(self, msg):
        act_id = msg["id"]
        res_type = msg.get("type", 0)
        fields = msg.get("fields", [])
        act_type = self._activities.get(act_id, 0)

        if res_type != _RES_PROGRESS or len(fields) < 2:
            return
        if act_type == _ACT_BUILDS:
            self._per_act_progress[(act_type, act_id)] = (
                "builds",
                fields[0],
                fields[1],
            )
            self._recompute_counts()
        elif act_type == _ACT_COPY_PATHS:
            self._per_act_progress[(act_type, act_id)] = (
                "copies",
                fields[0],
                fields[1],
            )
            self._recompute_counts()
        elif act_type == _ACT_COPY_PATH:
            self._copy_bytes[act_id] = (fields[0], max(fields[1], 1))

    def _update(self):
        count_total = self._builds_expected + self._copies_expected
        count_done = self._builds_done + self._copies_done
        if count_total <= 0:
            return

        # Prevents the channel copy (1 path) from dominating the
        # entire progress bar before the main build starts.
        effective_total = max(count_total, 3)
        count_frac = count_done / effective_total

        # large single-path copies move the bar.
        total_bytes = sum(t for _, t in self._copy_bytes.values())
        done_bytes = sum(d for d, _ in self._copy_bytes.values())
        if total_bytes > 0:
            byte_sub = done_bytes / total_bytes
            step = len(self._copy_bytes) / effective_total
            raw = count_frac + byte_sub * step
        else:
            raw = count_frac
        raw = max(0.0, min(1.0, raw))

        # When the denominator grows (e.g. main build discovers hundreds
        # of new paths), remap remaining work into remaining bar space.
        if raw >= self._floor:
            self._floor = raw
            self._floor_done = count_done
        else:
            new_items = count_done - self._floor_done
            remaining = effective_total - self._floor_done
            if remaining > 0 and new_items >= 0:
                raw = self._floor + (new_items / remaining) * (1.0 - self._floor)
            else:
                raw = self._floor
            raw = max(0.0, min(1.0, raw))
            if raw > self._floor:
                self._floor = raw
                self._floor_done = count_done

        self.fraction = raw

    def _recompute_counts(self):
        bd = be = cd = ce = 0
        for kind, done, expected in self._per_act_progress.values():
            if kind == "builds":
                bd += done
                be += expected
            else:
                cd += done
                ce += expected
        self._builds_done = bd
        self._builds_expected = be
        self._copies_done = cd
        self._copies_expected = ce


def run():
    """Install nire-testbed from the embedded flake."""

    INSTALL_PROGRESS_START = 0.1
    INSTALL_PROGRESS_END = 1.0

    global status
    status = _("Installing NixOS")
    libcalamares.job.setprogress(0.01)

    gs = libcalamares.globalstorage
    root_mount_point = gs.value("rootMountPoint")

    try:
        subprocess.check_output(
            ["pkexec", "chmod", "755", root_mount_point],
            stderr=subprocess.STDOUT,
        )
    except subprocess.CalledProcessError as e:
        libcalamares.utils.warning(
            "Failed to set permissions on {}: {}".format(root_mount_point, e.output)
        )

    status = _("Installing NixOS")
    libcalamares.job.setprogress(INSTALL_PROGRESS_START)

    # path:/etc/nixos-configs -- this image's own embedded, read-only copy of
    # the flake (environment.etc."nixos-configs", installer-configuration.nix).
    # #nire-testbed hardcoded: nire-installer's sole purpose is installing
    # this one host -- see installer-configuration.nix's header.
    nixosInstallCmd = ["pkexec"] + generateProxyStrings() + [
        "nixos-install",
        "--no-root-passwd",   # headless: nothing behind this Popen can answer
                               # an interactive root-password prompt.
        "--root", root_mount_point,
        "--flake", "path:/etc/nixos-configs#nire-testbed",
        "--log-format", "internal-json",
        "--option", "build-dir", "/nix/var/nix/builds",
    ]

    progress = NixProgress()

    try:
        output = ""
        proc = subprocess.Popen(
            nixosInstallCmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        while True:
            line = proc.stdout.readline().decode("utf-8")
            if not line:
                break

            was_json = progress.handle(line)

            # Keep output for error reporting
            if not was_json:
                output += line
            for log_line in progress.log_messages:
                output += log_line + "\n"

            mapped = INSTALL_PROGRESS_START + progress.fraction * (
                INSTALL_PROGRESS_END - INSTALL_PROGRESS_START
            )
            libcalamares.job.setprogress(mapped)

            for log_line in progress.log_messages:
                libcalamares.utils.debug("nixos-install: {}".format(log_line))
            progress.log_messages.clear()

            if not was_json:
                libcalamares.utils.debug("nixos-install: {}".format(line.strip()))

        exit = proc.wait()
        if exit != 0:
            return (_("nixos-install failed"), _(output))
    except Exception:
        return (_("nixos-install failed"), _("Installation failed to complete"))

    libcalamares.job.setprogress(INSTALL_PROGRESS_END)
    return None
