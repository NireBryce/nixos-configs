#!/usr/bin/env python3
"""recurring.py's shape step is a privacy boundary: nothing literal from a
command may survive into a shape. Two checks, the first the real one:

  - closed vocabulary: every token of every shape is a typed placeholder
    (<path>, <n>, <str>, <var>, <url>, <word>, <heredoc>, <loop>, <func>,
    <cmd>), -N, `--`, `-`, a command name the pinned allowlist knows, a
    SUBCOMMANDS word, or a flag of the permitted forms. A literal can only get out by looking
    like one of those, which is what the second check probes.
  - named literals: specific strings from hostile commands must not appear.

Cases are the ones that actually leaked: the first, regex-split version
(`git.moose"`, `infra-notes"` as fake commands) and a 2026-09-29 review of
the fix (`-uadmin`, `for host in`, `sudo -u host`, `env -C /x/dir`,
`-- -host`, quoted `"-hello"`), plus the shapes the fix must still get
right, multi-line and heredoc commit messages included. Stdlib only; the
command allowlist is pinned so results don't depend on the host's PATH.
"""
import json
import re
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import recurring as r  # noqa: E402

KNOWN = {'git', 'gh', 'nix', 'grep', 'sed', 'cat', 'head', 'tail', 'echo',
         'ls', 'find', 'ssh', 'curl', 'jq', 'sops', 'cut', 'wc', 'python3',
         'host', 'id', 'dir', 'printf', 'sort', 'uniq', 'stat', 'test',
         'mkdir', 'rm', 'du', 'xargs', 'sh', 'bash', 'eval'}
r.is_command = lambda name: name in KNOWN


def vocabulary():
    words = (set(KNOWN) | r.FIND_OPTS
             | {'<cmd>', '-N', '--', '-', '<loop>', '<func>', '<heredoc>'}
             | {f'<{t}>' for t in TYPES})
    def walk(subs):
        for k, v in (subs.items() if isinstance(subs, dict) else
                     ((w, None) for w in subs)):
            words.add(k)
            if v:
                walk(v)
    for tool, subs in r.SUBCOMMANDS.items():
        walk(subs)
    return words


TYPES = ('path', 'n', 'str', 'var', 'url', 'word', 'heredoc')
VOCAB = vocabulary()
FLAG_FORMS = re.compile(r'^(-[A-Za-z]{1,3}|-[A-Za-z]<val>'
                        r'|--[A-Za-z][A-Za-z0-9-]*(=<(%s)>)?)$' % '|'.join(TYPES))

# Credential-shaped fixtures are assembled at runtime so this file never
# contains one literally: secret scanners (the repo's guard hooks,
# GitGuardian on PRs -- it flagged a literal `curl -u user:pass` here in
# #429) match source text, not intent.
TSKEY = 'tsk' + 'ey-EXAMPLE'
USERPASS = ':'.join(['admin', 'hunter2'])

# (command, literals that must not appear in any shape)
LEAKS = [
    ('grep -n "persist\\|home\\|git.moose" wiki/hosts.md | head -20',
     ['persist', 'home', 'moose', 'hosts.md']),
    ("grep -A4 -i 'Host ts-cube\\|git.moose' ~/.ssh/config | grep -i identityfile",
     ['ts-cube', 'moose', 'identityfile', '.ssh']),
    ('f=$(grep -rl "services.forgejo" flake/modules | head -3); echo "$f"; '
     'grep -n -i "DEFAULT_PRIVATE\\|repository" $f',
     ['forgejo', 'flake', 'DEFAULT_PRIVATE', 'repository']),
    ('tok=$(sops -d --extract \'["forgejo-token"]\' low-side/secrets.yaml) && '
     'curl -sS -H "Authorization: token $tok" https://git.example.ts.net/api/v1 | jq .name',
     ['forgejo-token', 'secrets.yaml', 'Authorization', 'example', '$tok']),
    ('timeout 20 ssh -o BatchMode=yes ts-cube \'hostname; systemctl show -p User\'',
     ['ts-cube', 'BatchMode', 'hostname', 'User']),
    ('cut -c1-400 notes.txt 2>/dev/null', ['400', 'notes', '/dev/null']),
    (f"python3 - <<'EOF'\nimport secret_module\nprint('{TSKEY}')\nEOF",
     ['secret_module', 'EXAMPLE']),
    ('for h in cube durandal; do echo "== $h"; done', ['cube', 'durandal', '==']),
    ('git checkout experimental && git branch -d feat/private-thing',
     ['experimental', 'private-thing']),
    ('echo `cat /run/secrets/key`', ['/run/secrets', 'secrets']),
    ('unbalanced "quote | grep x', ['unbalanced', 'quote']),
    # from the review of the fix
    (f'curl -u{USERPASS} https://x', ['admin', 'hunter2']),
    ('ssh -lroot h', ['root']),
    ('grep -e "-secretpat" f', ['secretpat']),
    ('git commit -m "-hello world"', ['hello']),
    ('grep -- -host f', ['-host']),
    ('curl -H"X-Tok: abc" u', ['Tok', 'abc']),
    ('for host in a b; do ls; done', ['host']),
    ('for id in 1 2; do echo $id; done', ['id']),
    ('sudo -u host git status', ['host']),
    ('env -C /secret/dir git status', ['dir', 'secret']),
    ('host() { echo hi; }; host', ['host']),   # the call, too: a user-chosen name
    ('case "$x" in host) echo;; esac', ['host']),
    ('cat <<END-OF\nsecret body\nEND-OF', ['OF', 'secret', 'body']),
    (f"bash -c 'curl -u{USERPASS} x'", ['admin', 'hunter2']),
    ('echo $(git log)|head foo', ['foo']),
    # from auditing the first real export (2026-09-29): prose in quoted
    # bodies parsed as commands whenever a word was also a real program
    ('gh issue comment 1 --body "a \"quoted\" word\n\nsketch (shape only) \\`id\\` done"',
     ['shape', 'sketch', 'quoted', 'id']),
    ('gh pr create --body "run `grep x` then (shape only)"', ['shape', 'grep x']),
    ('for f in a; do n=$(awk -F\'"\' \'{print}\' $f | wc -w); echo "$(wc -w < $f) w $f"; done',
     [' w ', 'awk -F']),
]

SHAPES = [
    ('sed -n 40,80p a.nix && echo --- && sed -n 1,20p b.md',
     ['sed -n <n> <path>', 'echo <word>', 'sed -n <n> <path>']),
    ('git -C /some/dir log --oneline -5', ['git log --oneline -N']),
    ('timeout 20 git fetch origin', ['git fetch <word>']),
    ('git worktree add -q /tmp/wt -b feat/x origin/experimental',
     ['git worktree add -q <path> -b <path>']),
    ('gh pr view 12 --json url,title', ['gh pr view <n> --json <word>']),
    ('nix flake check --no-build', ['nix flake check --no-build']),
    ('cat x 2>&1 | head -30', ['cat <word>', 'head -N']),
    ('./scripts/whatever.sh --flag value', ['<cmd>']),
    ('X=1 FOO=bar grep -rn pat .', ['grep -rn <word> <path>']),
    ('echo hi\ngit status\nls foo', ['echo <word>', 'git status', 'ls <word>']),
    ('git add -A && git commit -q -m "$(cat <<\'EOF\'\nfix: x\n\nbody\nEOF\n)"',
     ['git add -A', 'git commit -q -m <str>']),
    ('find . -maxdepth 2 -type f | sort',
     ['find <path> -maxdepth <n> -type <word>', 'sort']),
    # typed placeholders: what kind of thing was removed, never the thing
    (f'curl -u{USERPASS} https://x', ['curl -u<val> <url>']),
    ('git log --format="%h" -5', ['git log --format=<str> -N']),
    ('cat $f ~/x/*.md', ['cat <var> <path>']),
    ("python3 - <<'EOF'\nx\nEOF", ['python3 - <heredoc>']),
    ('for h in a b; do ls; done', ['<loop>', 'ls']),
    ('host() { echo; }', ['<func>', 'echo']),
]

PIPELINES = [
    ('(cd sub && git log)|grep needle', [['git log', 'grep <word>']]),  # subshell output, piped
    ('cat a | head -5 && git status -sb', [['cat <word>', 'head -N'], ['git status -sb']]),
]


def all_cases():
    return [c for c, _ in LEAKS] + [c for c, _ in SHAPES] + [c for c, _ in PIPELINES]


class ShapeLeaks(unittest.TestCase):
    def test_closed_vocabulary(self):
        for cmd in all_cases():
            for seg in r.shape(cmd):
                for tok in seg.split():
                    with self.subTest(cmd=cmd, token=tok):
                        self.assertTrue(tok in VOCAB or FLAG_FORMS.match(tok),
                                        f'{tok!r} is outside the vocabulary')

    def test_no_named_literal(self):
        for cmd, literals in LEAKS:
            out = ' '.join(r.shape(cmd))
            for lit in literals:
                with self.subTest(cmd=cmd, literal=lit):
                    self.assertNotIn(lit, out)

    def test_shapes(self):
        for cmd, want in SHAPES:
            with self.subTest(cmd=cmd):
                self.assertEqual(r.shape(cmd), want)

    def test_pipelines(self):
        for cmd, want in PIPELINES:
            with self.subTest(cmd=cmd):
                self.assertEqual(r.pipelines(cmd), want)



class Export(unittest.TestCase):
    """What leaves the machine: an export file. Same closed vocabulary as
    the shapes, session ids hashed, nothing else."""

    def rows(self):
        return [(f'sess-{i % 3}', c) for i, c in enumerate(all_cases())]

    def test_export_is_vocabulary_only(self):
        doc = r.to_json(r.collect(self.rows(), 'claude'))
        for h in doc['sessions']:
            self.assertRegex(h, r'^[0-9a-f]{12}$')
        for kind in ('chains', 'pipes'):
            for key, hashes in doc[kind].items():
                for tok in key.replace('\t', ' ').split():
                    with self.subTest(kind=kind, token=tok):
                        self.assertTrue(tok in VOCAB or FLAG_FORMS.match(tok),
                                        f'{tok!r} would be exported')
                self.assertTrue(set(hashes) <= set(doc['sessions']))
        self.assertNotIn('sess-', json.dumps(doc))   # raw session ids stay home
        for cmd, literals in LEAKS:    # each case alone: literals are per case
            blob = json.dumps(r.to_json(r.collect([('s', cmd)], 'claude')))
            for lit in literals:
                with self.subTest(cmd=cmd, literal=lit):
                    self.assertNotIn(lit, blob)

    def test_json_roundtrip_and_merge(self):
        a = r.collect(self.rows()[:10], 'claude')
        b = r.collect(self.rows()[5:], 'claude')
        merged = r.merge(r.from_json(json.loads(json.dumps(r.to_json(a)))), b)
        whole = r.collect(self.rows(), 'claude')
        self.assertEqual(r.to_json(merged)['chains'], r.to_json(whole)['chains'])
        self.assertEqual(set(merged['sessions']), set(whole['sessions']))

    def test_rank_counts_sessions_not_uses(self):
        rows = [('s1', 'git fetch origin && git status -sb')] * 5 + \
               [('s2', 'git fetch up && git status -sb')]
        seq = r.rank(r.collect(rows, 'claude'), 1, 5, 4)['sequences']
        self.assertEqual(seq, [{'sessions': 2,
                                'chain': ['git fetch <word>', 'git status -sb']}])


class SqliteReader(unittest.TestCase):
    """OpenCode and zcode: `part` rows, tool bash or Bash, sessions
    filtered to this repo by directory."""

    def test_reads_bash_parts_in_this_repo_only(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'db.sqlite'
            db = sqlite3.connect(path)
            db.execute('create table session (id text, directory text)')
            db.execute('create table part (id text, session_id text, data text)')
            db.executemany('insert into session values (?, ?)', [
                ('s1', '/home/u/nixos-configs'), ('s2', '/home/u/elsewhere')])
            part = lambda tool, cmd: json.dumps(
                {'type': 'tool', 'tool': tool, 'callID': 'c',
                 'state': {'input': {'command': cmd}}})
            db.executemany('insert into part values (?, ?, ?)', [
                ('p1', 's1', part('bash', 'git status')),     # opencode
                ('p2', 's1', part('Bash', 'ls')),             # zcode
                ('p3', 's1', part('edit', 'not a command')),
                ('p4', 's2', part('bash', 'other repo')),
                ('p5', 's1', 'not json'),
            ])
            db.commit()
            db.close()
            self.assertEqual(list(r.sqlite_rows(path)),
                             [('s1', 'git status'), ('s1', 'ls')])

    def test_unreadable_db_yields_nothing(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'empty.sqlite'
            sqlite3.connect(path).close()      # no tables
            self.assertEqual(list(r.sqlite_rows(path)), [])


if __name__ == '__main__':
    unittest.main()
