"""Shared by doc_drift.py and doc_partition.py: which docs are in scope,
and which repo paths a doc cites. Stdlib only; read-only.

Scope: wiki/**/*.md (config-structure/categories/, homelab/, experiments/, agent-lessons-learned/
included), .agents/rules/*.md, .agents/skills/*/SKILL.md, AGENTS.md.
Symlinks (wiki/README.md, the rules and skills links) are in scope as
paths; callers decide whether to follow them.

Citation extraction mirrors wiki/meta/scripts/wiki_stale_refs.py (backtick
tokens, shortened paths matched by suffix, `normalize` imported from it),
widened to markdown link targets and to directories.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "wiki" / "meta" / "scripts"))

BACKTICK = re.compile(r"`([^`\n]+)`")
MDLINK = re.compile(r"\]\(([^)\s#]+)(?:#[^)]*)?\)")
DATE = re.compile(r"^_Last modified:\s*(\d{4}-\d{2}-\d{2})_", re.M)
EXTS = (".nix", ".py", ".sh", ".md", ".yaml", ".yml", ".json", ".toml",
        ".just", ".justfile")
MAX_AMBIGUOUS = 1  # a short name matching more tracked paths than this is skipped


def normalize(token):
    try:
        from wiki_stale_refs import normalize as normalize_name
        return normalize_name(token)
    except ImportError:  # fixture repos have no wiki/meta/scripts
        return "/".join(part for part in token.split("/") if part not in (".", ".."))


def git(root, *args):
    completed = subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                       text=True)
    return completed.stdout if completed.returncode == 0 else ""


def docs(root):
    """Sorted repo-relative posix paths of every in-scope doc."""
    root = Path(root)
    found = set(root.joinpath("wiki").rglob("*.md")) if (root / "wiki").is_dir() else set()
    found |= set(root.glob(".agents/rules/*.md"))
    found |= set(root.glob(".agents/skills/*/SKILL.md"))
    if (root / "AGENTS.md").exists():
        found.add(root / "AGENTS.md")
    return sorted(path.relative_to(root).as_posix() for path in found
                  if "__pycache__" not in path.parts)


class Index:
    """Tracked files and directories, for resolving a cited token."""

    def __init__(self, root):
        self.files = set(git(root, "ls-files").splitlines())
        self.dirs = {"/".join(file_name.split("/")[:depth]) for file_name in self.files
                     for depth in range(1, file_name.count("/") + 1)}
        self.all = self.files | self.dirs
        self.by_name = {}
        for path in self.all:
            parts = path.split("/")
            for depth in range(len(parts)):
                self.by_name.setdefault("/".join(parts[depth:]), []).append(path)

    def resolve(self, token):
        """Repo path for a cited token or None (unknown, ambiguous, or a
        bare word)."""
        target = normalize(token.strip().rstrip("/"))
        target = re.sub(r":\d+(-\d+)?$", "", target)
        if not target or any(char in target for char in " *<>{}$|()=") or target.startswith(("http", "~")):
            return None
        if "/" not in target and not target.endswith(EXTS):
            return None
        if target in self.all:
            return target
        hits = self.by_name.get(target, [])
        return hits[0] if len(hits) <= MAX_AMBIGUOUS and hits else None


def cited(text, index):
    """Set of tracked repo paths (files or dirs) the text cites."""
    out = set()
    for rx in (BACKTICK, MDLINK):
        for match in rx.finditer(text):
            path = index.resolve(match.group(1))
            if path:
                out.add(path)
    return out


def last_modified(root, rel):
    """(date, source): the `_Last modified:_` line, else last commit date."""
    text = (Path(root) / rel).read_text(errors="replace")
    match = DATE.search(text)
    if match:
        return match.group(1), "line"
    commit_date = git(root, "log", "-1", "--format=%cs", "--", rel).strip()
    return (commit_date or None), "git"
