#!/usr/bin/env python3
"""statix + deadnix + an oversized-file check, ratcheted against a committed
baseline so a commit can lower the finding count but never raise it.

Neither `nix flake check` nor `modules.py` catches nix-antipattern lint
(statix) or dead code (deadnix) -- both were already installed as home-manager
packages (nirePackages/nix-utils/{statix,deadnix}/) for a human to run by
hand, but nothing ran them. Wired in here rather than as a bare `nix flake
check` addition because a lint tool, unlike an evaluator, has an opinion --
running it once and requiring a clean tree would mean fixing (or `-i`-globbing
around) every one of the 170-odd pre-existing statix findings and 3 deadnix
ones before this could land at all, which is disproportionate to what this
repo actually needs (CLAUDE.md, "Calibrate severity"). The ratchet is the
compromise: today's counts become the baseline, so nothing already here is an
error, but a commit that adds a NEW finding is one, and a commit that fixes
one lowers the bar for every commit after it -- the number can go down by
accident (fixing something for an unrelated reason still lowers it) but can
never quietly go back up.

The oversized-file check lives in the same script and baseline, not a
separate one, for the same reason `modules.py check` folds collisions and
orphans together: one ratchet, one number per category, one place that knows
how to compare them.

    lint.py check              # compare current counts to the baseline; the
                                # normal path, used by `just lint` and CI.
                                # Exits 1 if any category regressed.
                                # Auto-lowers (and rewrites) the baseline file
                                # in place if any category improved -- the
                                # caller is expected to `git add` it back;
                                # the pre-commit hook does this itself.
    lint.py show                # current counts, findings listed, no baseline
                                # comparison and no exit-code judgement. For
                                # a human checking "what's actually flagged"
                                # without touching the ratchet.
    lint.py bootstrap           # write the current counts as the baseline,
                                # unconditionally -- not part of the normal
                                # flow. Only for deliberately accepting
                                # today's findings as the new floor (first
                                # setup, or a decision that a batch of
                                # findings is being knowingly left for later).
"""
import json, pathlib, subprocess, sys

SCRIPT_DIR      = pathlib.Path(__file__).resolve().parent
BASELINE_PATH   = SCRIPT_DIR / 'lint-baseline.json'
FLAKE_ROOT      = SCRIPT_DIR.parent               # flake/scripts/ -> flake/
OVERSIZED_LIMIT = 5000


def repo_root():
    out = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                          capture_output=True, text=True, check=True)
    return pathlib.Path(out.stdout.strip())


def run_tool(argv, tool_name):
    try:
        return subprocess.run(argv, capture_output=True, text=True, cwd=FLAKE_ROOT)
    except FileNotFoundError:
        print(f"lint.py: {tool_name!r} not on PATH -- it's a home-manager package "
              f"(nirePackages/nix-utils/{tool_name}/) on a real host, but CI and a "
              f"bare devshell need `nix shell nixpkgs#{tool_name}` first.",
              file=sys.stderr)
        sys.exit(2)


def statix_findings():
    """[(file, line, note, message), ...]. statix emits pretty-printed JSON
    objects back-to-back with no separator or enclosing array, so a plain
    json.load can't parse the stream -- decode one object at a time instead."""
    proc = run_tool(['statix', 'check', '-o', 'json', '.'], 'statix')
    dec, data, i, out = json.JSONDecoder(), proc.stdout, 0, []
    while i < len(data):
        while i < len(data) and data[i] in ' \t\r\n':
            i += 1
        if i >= len(data):
            break
        obj, i = dec.raw_decode(data, i)
        for report in obj.get('report', []):
            for diag in report.get('diagnostics', []):
                line = diag.get('at', {}).get('from', {}).get('line', '?')
                out.append((obj['file'], line, report.get('note', ''), diag.get('message', '')))
    return out


def deadnix_findings():
    """[(file, line, message), ...]. One JSON object per line, unlike statix."""
    proc = run_tool(['deadnix', '-o', 'json', '.'], 'deadnix')
    out = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        for r in obj.get('results', []):
            out.append((obj['file'], r.get('line', '?'), r.get('message', '')))
    return out


def oversized_files(limit=OVERSIZED_LIMIT):
    """[(path, line_count), ...] for every git-tracked file over `limit` lines.

    Repo-wide, not flake/-only -- CLAUDE.md itself is the file most likely to
    hit this, and it lives at the repo root. Tracked files only, same reason
    the flake itself only sees tracked files (CLAUDE.md, "git add before nix
    eval"): an untracked scratch file blowing past the limit isn't this
    repo's problem yet.
    """
    root = repo_root()
    out = subprocess.run(['git', 'ls-files', '-z'], capture_output=True,
                          text=True, cwd=root, check=True)
    hits = []
    for name in out.stdout.split('\0'):
        if not name:
            continue
        p = root / name
        if not p.is_file():
            continue
        try:
            n = sum(1 for _ in p.open('rb'))
        except OSError:
            continue
        if n > limit:
            hits.append((name, n))
    return hits


def load_baseline():
    if not BASELINE_PATH.exists():
        return {'statix': 0, 'deadnix': 0, 'oversized_files': 0}
    return json.loads(BASELINE_PATH.read_text())


def save_baseline(counts):
    BASELINE_PATH.write_text(json.dumps(counts, indent=2, sort_keys=True) + '\n')


def report(label, findings, fmt):
    if not findings:
        return
    print(f"\n-- {label} ({len(findings)}) --")
    for f in findings:
        print(fmt(f))


def gather():
    statix   = statix_findings()
    deadnix  = deadnix_findings()
    oversize = oversized_files()
    counts = {'statix': len(statix), 'deadnix': len(deadnix),
              'oversized_files': len(oversize)}
    return counts, statix, deadnix, oversize


def show():
    counts, statix, deadnix, oversize = gather()
    report('statix', statix, lambda f: f"{f[0]}:{f[1]}: {f[2]} -- {f[3]}")
    report('deadnix', deadnix, lambda f: f"{f[0]}:{f[1]}: {f[2]}")
    report('oversized files (>%d lines)' % OVERSIZED_LIMIT, oversize,
           lambda f: f"{f[0]}: {f[1]} lines")
    print(f"\n{counts}")
    return 0


def check():
    counts, statix, deadnix, oversize = gather()
    baseline = load_baseline()

    regressed = {k: (baseline.get(k, 0), v) for k, v in counts.items()
                 if v > baseline.get(k, 0)}
    improved  = {k: (baseline.get(k, 0), v) for k, v in counts.items()
                 if v < baseline.get(k, 0)}

    if regressed:
        report('statix', statix, lambda f: f"{f[0]}:{f[1]}: {f[2]} -- {f[3]}")
        report('deadnix', deadnix, lambda f: f"{f[0]}:{f[1]}: {f[2]}")
        report('oversized files (>%d lines)' % OVERSIZED_LIMIT, oversize,
               lambda f: f"{f[0]}: {f[1]} lines")
        print("\nlint: REGRESSION -- this commit raises the baseline:")
        for k, (was, now) in regressed.items():
            print(f"  {k}: {was} -> {now}  (+{now - was})")
        print(f"\nbaseline file: {BASELINE_PATH.relative_to(repo_root())}")
        return 1

    if improved:
        save_baseline(counts)
        for k, (was, now) in improved.items():
            print(f"lint: {k} improved: {was} -> {now}; lowered the baseline")
        print(f"baseline file rewritten: {BASELINE_PATH.relative_to(repo_root())} "
              f"-- add it to this commit")
        return 0

    print(f"lint: no change from baseline ({counts})")
    return 0


def bootstrap():
    counts, *_ = gather()
    save_baseline(counts)
    print(f"lint: baseline written: {counts}")
    return 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('check', 'show', 'bootstrap'):
        print(__doc__)
        sys.exit(2)
    action = {'check': check, 'show': show, 'bootstrap': bootstrap}[sys.argv[1]]
    sys.exit(action())


main()
