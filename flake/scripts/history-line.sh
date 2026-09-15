#! /usr/bin/env bash
# Print the 1-based line number of a .nix module's history section header --
# the bottom-of-file `# ── history ──` / `# history` heading that the repo's
# convention puts stranded bug records under (AGENTS.md, "a bug recorded in
# a comment stays in the file").
#
#     history-line.sh <file>              # e.g. prints 314
#
# The point is cheap partial reads: an agent browsing modules to find where
# something is configured wants the module, not its history -- read up to
# this line minus one (the Read tool's `limit`, or `head -n`) and skip the
# rest. Editing the module is different: the history exists precisely to be
# read before changing the thing it describes.
#
# When several lines look like a history heading (passing mentions such as
# "# history section below"), the LAST one wins -- the convention files the
# section at the bottom. No history section: exit 1, no output -- the exit
# code is the answer, the whole file is then fair game.
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "usage: history-line.sh <file>" >&2
    exit 2
fi
if [ ! -r "$1" ]; then
    echo "history-line.sh: cannot read '$1'" >&2
    exit 2
fi

# Heading-shaped lines only -- `#` comment, optional box-drawing run, then
# "history" at a word boundary -- so mid-comment mentions ("see the history
# section") don't count; they never start their line with the heading shape.
line=$(grep -n -iE '^[[:space:]]*#[[:space:]]*─*[[:space:]]*history([^[:alnum:]_]|$)' "$1" |
    tail -1 | cut -d: -f1)

[ -n "$line" ] || exit 1
echo "$line"
