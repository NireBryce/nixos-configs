#!/usr/bin/env bash
# Transform den-wrapped nix files into flat home-manager modules.
# Usage:
#   transform_den.sh file.nix          # print to stdout
#   transform_den.sh -i file.nix ...   # edit in place

AWK_PROG='
/^[[:space:]]*\{[[:space:]]*den\./  { next }
/^[[:space:]]*;\}/                  { next }
/^[[:space:]]*in[[:space:]]*$/      { next }

# Skip standalone "{ ... }:" outer wrapper lines
/^[[:space:]]*\{[[:space:]]*\.\.\.[[:space:]]*\}[[:space:]]*:/ { next }

# Single-line: "let packageList = with pkgs; ["
/^[[:space:]]*let[[:space:]]+[^=]+=[[:space:]]*with pkgs;[[:space:]]*\[/ { collecting=1; next }

# Multi-line: "let" alone, then variable assignment on next line
/^[[:space:]]*let[[:space:]]*$/     { waiting=1; next }
waiting && /=[[:space:]]*with pkgs;[[:space:]]*\[/ { collecting=1; waiting=0; next }
waiting                             { waiting=0 }

collecting && /\];/                 { collecting=0; next }
collecting                          { pkgs[n++]=$0; next }

# Only transform home.packages if we collected packages (n > 0)
/home\.packages[[:space:]]*=/ && n > 0 {
    match($0, /^[[:space:]]*/)
    indent=substr($0, 1, RLENGTH)
    print indent "home.packages = with pkgs; ["
    for (i=0; i<n; i++) {
        sub(/^[[:space:]]+/, "", pkgs[i])
        print indent "    " pkgs[i]
    }
    print indent "];"
    next
}
{ print }
'

in_place=0
[[ $1 == -i ]] && { in_place=1; shift; }

for f in "$@"; do
    if (( in_place )); then
        tmp=$(mktemp)
        awk "$AWK_PROG" "$f" > "$tmp" && mv "$tmp" "$f"
        echo "Updated: $f" >&2
    else
        awk "$AWK_PROG" "$f"
    fi
done
