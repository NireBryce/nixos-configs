#!/usr/bin/env python3
"""
Transform den-wrapped nix package files into flat home-manager modules.

Before:
  { den.aspects.pkgs-cli.homeManager =
  { pkgs, ... }:
  let packageList = with pkgs; [
      some-package
  ];
  in
  {
      home.packages = packageList;
  }
  ;}

After:
  { pkgs, ... }:
  {
      home.packages = with pkgs; [
          some-package
      ];
  }

Usage:
  python3 transform_den.py file.nix              # print to stdout
  python3 transform_den.py file.nix -i           # edit in place
  python3 transform_den.py *.nix -i              # batch in-place
  python3 transform_den.py file.nix -o out.nix   # write to new file
"""

import re
import sys
from pathlib import Path


def transform(content: str) -> str:
    lines = content.split("\n")
    result = []
    packages: list[str] = []
    i = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Drop: { den.some.path.attr =
        if re.match(r"\s*\{\s*den\.", line):
            i += 1
            continue

        # Drop: ;} (closing wrapper)
        if stripped == ";}":
            i += 1
            continue

        # Capture: let packageList = with pkgs; [
        if re.match(r"\s*let\s+\w+\s*=\s*with\s+pkgs;\s*\[", line):
            i += 1
            while i < len(lines) and lines[i].strip() not in ("];", "];"):
                pkg_line = lines[i]
                # Only collect non-empty lines
                if pkg_line.strip():
                    packages.append(pkg_line)
                i += 1
            i += 1  # skip the ]; line

            # Skip the bare 'in' line that follows
            if i < len(lines) and lines[i].strip() == "in":
                i += 1
            continue

        # Replace: home.packages = packageList;  →  inline with pkgs; [...]
        if re.match(r"\s*home\.packages\s*=\s*\w+;", line):
            indent = re.match(r"(\s*)", line).group(1)
            result.append(f"{indent}home.packages = with pkgs; [")
            for pkg in packages:
                # Normalise to indent + 4 extra spaces regardless of source indent
                pkg_name = pkg.strip()
                result.append(f"{indent}    {pkg_name}")
            result.append(f"{indent}];")
            i += 1
            continue

        result.append(line)
        i += 1

    # Trim any trailing blank lines and add a single newline at end
    while result and result[-1].strip() == "":
        result.pop()
    return "\n".join(result) + "\n"


def process_file(path: Path, in_place: bool, output: Path | None) -> None:
    content = path.read_text()
    transformed = transform(content)

    if in_place:
        path.write_text(transformed)
        print(f"Updated: {path}", file=sys.stderr)
    elif output:
        output.write_text(transformed)
        print(f"Written: {output}", file=sys.stderr)
    else:
        print(transformed, end="")


def main():
    args = sys.argv[1:]

    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)

    in_place = "-i" in args
    output_path: Path | None = None

    if "-o" in args:
        idx = args.index("-o")
        output_path = Path(args[idx + 1])
        args = args[:idx] + args[idx + 2:]

    if in_place:
        args.remove("-i")

    files = [Path(a) for a in args]

    if not files:
        print("Error: no input files specified.", file=sys.stderr)
        sys.exit(1)

    if output_path and len(files) > 1:
        print("Error: -o can only be used with a single input file.", file=sys.stderr)
        sys.exit(1)

    for f in files:
        if not f.exists():
            print(f"Error: {f} not found", file=sys.stderr)
            sys.exit(1)
        process_file(f, in_place, output_path)


if __name__ == "__main__":
    main()
