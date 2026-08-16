#!/usr/bin/env python3
"""Check calamares-settings.conf's trimmed sequence hasn't drifted.

Run by installer-checks.nix's installer-calamares-settings-conf check.
Real Python in its own file, not buried in a Nix runCommand string or a
shell script -- see CLAUDE.md, "Don't bury Python inside a bash script".

Not a general YAML validator (yaml.safe_load_all already does that, and
fails loudly with its own line numbers if the file is malformed) -- this
specifically pins down the trim installer-calamares.nix's header explains
and calamares-settings.conf's own comment documents, so a future edit that
silently re-adds a dropped page (or drops one meant to stay) fails a check
instead of only being caught by someone re-reading the diff.
"""
import sys

import yaml


def fail(msg):
    print(f"check-settings-conf: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    if len(sys.argv) != 2:
        fail("usage: check-settings-conf.py <settings.conf>")

    with open(sys.argv[1]) as f:
        text = f.read()

    # @out@ is a real, load-bearing placeholder (modules-search's own
    # line), substituted by installer-calamares.nix's postInstall at build
    # time via substituteInPlace, same as upstream's own installPhase does
    # for the stock file -- before that substitution, `@out@/...` isn't
    # even valid YAML (a bare leading `@` is a reserved indicator per the
    # YAML spec), so this check has to fake the same substitution before
    # parsing, not just before Calamares itself ever sees the file.
    text = text.replace("@out@", "/nix/store/00000000000000000000000000000000-placeholder")

    # settings.conf is a two-document YAML stream: a leading `---`
    # separates an all-comments (empty) document from the real one.
    docs = [d for d in yaml.safe_load_all(text) if d is not None]

    if len(docs) != 1:
        fail(f"expected exactly one non-empty YAML document, found {len(docs)}")

    settings = docs[0]
    sequence = settings.get("sequence")
    if not sequence:
        fail("no 'sequence' key found")

    show_phases = [phase["show"] for phase in sequence if "show" in phase]
    exec_phases = [phase["exec"] for phase in sequence if "exec" in phase]
    all_shown = {m for phase in show_phases for m in phase}
    all_exec = {m for phase in exec_phases for m in phase}

    # Deliberately dropped -- see installer-calamares.nix's header and this
    # file's own comment for why each one is dead weight once main.py no
    # longer generates a configuration.nix from wizard answers.
    must_not_show = {"locale", "users", "packagechooser", "notesqml@unfree"}
    must_not_exec = {"users"}

    # Must stay -- welcome/summary/finished are UI bookends, keyboard has a
    # live effect on the running session (keyboard.conf's
    # `configure: gnome: true`), partition/mount/nixos/umount are the actual
    # mechanism.
    must_show = {"welcome", "keyboard", "partition", "summary", "finished"}
    must_exec = {"partition", "mount", "nixos", "umount"}

    problems = []
    leaked_show = all_shown & must_not_show
    if leaked_show:
        problems.append(f"show phase still has dropped module(s): {sorted(leaked_show)}")
    leaked_exec = all_exec & must_not_exec
    if leaked_exec:
        problems.append(f"exec phase still has dropped module(s): {sorted(leaked_exec)}")
    missing_show = must_show - all_shown
    if missing_show:
        problems.append(f"show phase missing expected module(s): {sorted(missing_show)}")
    missing_exec = must_exec - all_exec
    if missing_exec:
        problems.append(f"exec phase missing expected module(s): {sorted(missing_exec)}")

    if problems:
        for p in problems:
            print(f"check-settings-conf: {p}", file=sys.stderr)
        sys.exit(1)

    print("check-settings-conf: sequence matches the documented trim -- "
          f"show={sorted(all_shown)} exec={sorted(all_exec)}")


if __name__ == "__main__":
    main()
