"""Shared by doc_drift.py and doc_partition.py: which docs are in scope,
and which repo paths a doc cites. Stdlib only; read-only.

Scope: wiki/**/*.md (categories/, homelab/, experiments/, agent-lessons-learned/
included), .agents/rules/*.md, .agents/skills/*/SKILL.md, AGENTS.md.
Symlinks (wiki/README.md, the rules and skills links) are in scope as
paths; callers decide whether to follow them.

Citation extraction mirrors wiki/scripts/wiki_stale_refs.py (backtick
tokens, shortened paths matched by suffix, `normalize` imported from it),
widened to markdown link targets and to directories.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "wiki" / "scripts"))

BACKTICK = re.compile(r"`([^`\n]+)`")
MDLINK = re.compile(r"\]\(([^)\s#]+)(?:#[^)]*)?\)")
DATE = re.compile(r"^_Last modified:\s*(\d{4}-\d{2}-\d{2})_", re.M)
EXTS = (".nix", ".py", ".sh", ".md", ".yaml", ".yml", ".json", ".toml",
        ".just", ".justfile")
MAX_AMBIGUOUS = 1  # a short name matching more tracked paths than this is skipped


def normalize(token):
    try:
        from wiki_stale_refs import normalize as n
        return n(token)
    except ImportError:  # fixture repos have no wiki/scripts
        return "/".join(p for p in token.split("/") if p not in (".", ".."))


def git(root, *args):
    p = subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                       text=True)
    return p.stdout if p.returncode == 0 else ""


def docs(root):
    """Sorted repo-relative posix paths of every in-scope doc."""
    root = Path(root)
    found = set(root.joinpath("wiki").rglob("*.md")) if (root / "wiki").is_dir() else set()
    found |= set(root.glob(".agents/rules/*.md"))
    found |= set(root.glob(".agents/skills/*/SKILL.md"))
    if (root / "AGENTS.md").exists():
        found.add(root / "AGENTS.md")
    return sorted(p.relative_to(root).as_posix() for p in found
                  if "__pycache__" not in p.parts)


class Index:
    """Tracked files and directories, for resolving a cited token."""

    def __init__(self, root):
        self.files = set(git(root, "ls-files").splitlines())
        self.dirs = {"/".join(f.split("/")[:i]) for f in self.files
                     for i in range(1, f.count("/") + 1)}
        self.all = self.files | self.dirs
        self.by_name = {}
        for p in self.all:
            parts = p.split("/")
            for i in range(len(parts)):
                self.by_name.setdefault("/".join(parts[i:]), []).append(p)

    def resolve(self, token):
        """Repo path for a cited token or None (unknown, ambiguous, or a
        bare word)."""
        t = normalize(token.strip().rstrip("/"))
        t = re.sub(r":\d+(-\d+)?$", "", t)
        if not t or any(c in t for c in " *<>{}$|()=") or t.startswith(("http", "~")):
            return None
        if "/" not in t and not t.endswith(EXTS):
            return None
        if t in self.all:
            return t
        hits = self.by_name.get(t, [])
        return hits[0] if len(hits) <= MAX_AMBIGUOUS and hits else None


def cited(text, index):
    """Set of tracked repo paths (files or dirs) the text cites."""
    out = set()
    for rx in (BACKTICK, MDLINK):
        for m in rx.finditer(text):
            p = index.resolve(m.group(1))
            if p:
                out.add(p)
    return out


def last_modified(root, rel):
    """(date, source): the `_Last modified:_` line, else last commit date."""
    text = (Path(root) / rel).read_text(errors="replace")
    m = DATE.search(text)
    if m:
        return m.group(1), "line"
    d = git(root, "log", "-1", "--format=%cs", "--", rel).strip()
    return (d or None), "git"
