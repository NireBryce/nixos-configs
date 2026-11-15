# 54. Name variables for what they hold

_Last modified: 2026-11-15_

## Index entry

§54 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

The scripts and their tests were full of one-character names: `r`, `p`, `m`,
`d`, `f`, `k`, `v`. Reading a function meant tracing each letter back to its
assignment to learn what it was, and the same letter meant different things
from one function to the next. In the test files, `r` was a subprocess result
in some tests and a git repository path in others. In `test_recurring.py` it
was the imported `recurring` module (`import recurring as r`), so a rename of
`r` to `result` in each function broke every function that used the module.

Cleaning this up across the Python in `flake/scripts/`, `.agents/scripts/` and
`tools/docchecks/` took hundreds of renames. Three things went wrong on the
way, each caught only by a test or `ruff`, never by the rename itself:

- An AST rename by position missed names inside f-strings that span lines
  (`f"{articles[n].name}"`), and missed an `import x as n` alias. `py_compile`
  accepted both; the error would have been a `NameError` at runtime. `ruff
  check --select F821` found them.
- A helper took a keyword argument by its old name (`feature(n=2)`) and
  another swallowed it silently through `**over`. The tests failed only
  because the fixture then built the wrong number of commits.
- One letter used for two meanings in a function (a signal and a step both
  `s`) became one new name for both.
- A default letter-to-name map applied across many functions gave names that
  ran fine and were wrong: `p` became `proc` where it held a path, `c` became
  `class_name` where it held a category. No test, `ruff` or `py_compile`
  caught these. Reading the diff did.

## The rule

Name a variable for what it holds: `result`, `repo`, `match`, `path`, `line`,
`worktree`. `_` for a value that is ignored is the only one-character name.
This covers loop variables, comprehension variables, lambda parameters and
`except ... as` names. Don't alias an import to a letter.

Rename by the syntax tree, not by text, then run `ruff check --select F821`
and the file's tests, and grep for keyword callers of any renamed parameter
(a keyword argument names the old parameter). Read the diff of every line a
bulk rename touched; where one letter had more than one meaning, name each
function's use separately.

## Related

§1 (a new checker is tested against a case it should catch), §20 (read the
output, not the status). Enforced by `flake/scripts/short_names.py` (preflight
step `just short-names`, fixture test `tests/test_short_names.py`). Files not
yet cleaned are listed in `flake/scripts/short-names-baseline.json`, whose
counts may only fall.
