#!/usr/bin/env bash
# Show several files, ranges, or directories in one call, a header before
# each -- the batch read agents hand-assemble in most sessions (82% of 73
# at 2026-09-29: `sed -n A,Bp f; echo ---; cat g | head -N; ls d | head`).
#
#   show.sh [-n] SPEC...
#     SPEC  path           whole file (a directory is listed, not read)
#           path:A-B       lines A through B
#           path:A         line A to the end
#           path:-B        lines 1 through B
#     -n    prefix each line with its line number
#
# Headers are `==> path:A-B <==`, the format `head`/`tail` print for
# several files. A missing path prints its header and `(missing)` and the
# rest still run; the exit status is 1 if any were missing.
set -uo pipefail

number=false
[[ ${1:-} == -n ]] && { number=true; shift; }
[[ $# -gt 0 ]] || { sed -n '6,12s/^# \{0,1\}//p' "$0"; exit 2; }

status=0
for spec in "$@"; do
    path=${spec%:*} range=${spec##*:}
    # No colon, or one that's part of the name rather than a range: whole file.
    if [[ $spec != *:* || ! $range =~ ^[0-9]*(-[0-9]*)?$ ]]; then
        path=$spec range=
    fi
    start=${range%-*} end=${range#*-}
    [[ $range == *-* ]] || end=
    start=${start:-1} end=${end:-\$}

    echo "==> $path${range:+:$range} <=="
    if [[ -d $path ]]; then
        ls -la "$path"
    elif [[ -r $path ]]; then
        if $number; then
            sed -n "${start},${end}{=;p}" "$path" | sed 'N;s/\n/\t/'
        else
            sed -n "${start},${end}p" "$path"
        fi
    else
        echo "(missing)"
        status=1
    fi
    echo
done
exit $status
