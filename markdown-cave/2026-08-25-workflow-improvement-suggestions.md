## context

Ran `.claude/todo.md`'s 7-item checklist this session (memory scan, CLAUDE.md
scan, skill scan, linter + filesize rule, error-count ratchet, this file,
archive the todo). This note is item 6: what got done, what was considered
and rejected, and what's left as an idea rather than a change.

## what actually got wired in

- **`just lint`** (`flake/scripts/lint.py`): statix + deadnix + a 5000-line
  file-size cap, all git-tracked files. Ratcheted against a committed
  baseline (`flake/scripts/lint-baseline.json`, seeded at today's real
  counts: 170 statix, 3 deadnix, 0 oversized) rather than requiring every
  pre-existing finding fixed before it could land — see the script's own
  header for why. Wired into CI (`.github/workflows/check.yml`) and into a
  local `.githooks/pre-commit` (opt-in via `just install-hooks`).
- **`.githooks/commit-msg`**: auto-corrects a `Co-Authored-By: Claude <model
  name> <noreply@anthropic.com>` trailer to the canonical form. CLAUDE.md
  already names 82+54 wrong trailers from exactly this and explains why an
  agent can't self-check it (the model name comes from the system prompt,
  which the agent has no way to verify) — so this is a mechanical fix for a
  mistake CLAUDE.md itself says isn't catchable by re-reading.
- **`modules.py untracked`**: reports a `.nix` file under `modules/` that
  `git` doesn't know about yet, folded into `just modules`. Direct
  mechanization of CLAUDE.md's "`git add` before `nix eval`" trap.
- **`just preflight`**: `check` + `modules` + `lint` in one recipe — what the
  `ship` skill's step 0 already asked a session to run by hand, now one
  command instead of three to remember.
- **`propose-issue` skill, step 2**: was hand-grepping `CLAUDE.md` +
  `lessons-learned.md` and separately calling `gh issue list --search` —
  exactly what `flake/scripts/threads.sh` (`just threads`) already does in
  one shot, `investigate-bug` already uses it that way. Pointed step 2 at
  `just threads` instead of re-deriving the same check by hand.
- **One memory pruned**: `skill-descriptions-short.md` (the skill-description
  convention) is now fully superseded by the `new-skill` skill's own body,
  written after the memory. Repo content should win over a private memory
  once both say the same thing, so the memory came out rather than sitting
  as a stale duplicate. `MEMORY.md` is empty as of this session — it isn't
  a mistake, there's nothing left to index.

## considered, not done, and why

- **A settings.json deny-rule for `gh issue create --repo <not-this-repo>`**,
  to mechanically back up the "never file upstream without Elly saying so"
  rule. Rejected: Bash permission matching here is pattern/prefix-based, and
  `gh`'s repo argument can be spelled enough different ways (env var, a
  variable holding the string, `--repo=` vs `--repo `) that a deny-list would
  give false confidence rather than a real guarantee — worse than the current
  state, where the rule is a documented judgement call an agent has to reason
  about honestly. Automating the check without automating the judgement isn't
  a win here.
- **A lint rule for the `${...}`-inside-`''`-is-interpolation trap**
  (CLAUDE.md, Traps). Rejected: the actual failure mode is a template
  placeholder inside what *looks like* a comment inside a stage-1 hook
  string, and distinguishing "this `${...}` is a real trap" from "this
  `${...}` is a normal, intended interpolation" needs understanding the
  string's role, not just its syntax — a blanket lint would be mostly noise.
  Left as prose + the `impermanence-initrd` skill, which is the actual
  trigger point (touching initrd), not a rule anyone needs firing on every
  `.nix` file.
- **A pre-flight grep for `owner/repo#number` before filing anything on
  GitHub** (the autolinking trap, CLAUDE.md/Filing section). This one *is*
  mechanically checkable, but there's no natural hook point — it needs to run
  against an issue/PR body before a `gh issue create`/`gh pr create` call,
  and there's no commit or file-save event to hang it on the way the other
  two hooks have. Noting it here rather than building a wrapper script around
  `gh` itself, which felt like more infrastructure than the actual risk (one
  grep, run by hand, immediately before typing a specific issue/PR number)
  warrants.

## for later, if it's ever worth doing

- **`just lint`'s 170 pre-existing statix findings** are almost entirely one
  pattern (`dirsAsCategory.nix`'s `flake = {...}; flake = {...};` repeated
  keys, in every category — that's ~38 of the 170 right there) plus a
  handful of empty-pattern-argument warnings. A single mechanical rewrite of
  `dirsAsCategory.nix`'s template would clear most of the baseline in one
  change; didn't attempt it here since it touches every category and wasn't
  what was asked.
- **CI's lint step re-fetches `nixpkgs#statix nixpkgs#deadnix` from the
  binary cache on every run** (`nix shell nixpkgs#statix nixpkgs#deadnix`).
  Cheap, but if CI minutes ever start mattering here, pinning those two to
  the flake's own nixpkgs input (already in the tree as home-manager
  packages) and reusing that derivation would save the fetch.
- **Skill bodies vs. deterministic scripts, more broadly**: most of what's in
  `.claude/skills/*/SKILL.md` earns being a skill rather than a script
  precisely because it's judgement over Nix code, PR review, or wiki prose —
  not something a script can safely decide. The two real hits this pass
  found (`propose-issue` re-deriving `threads.sh`, `ship`'s three-command
  preflight) were both "an existing script already does this, the skill just
  didn't say so" — worth re-checking next time a skill grows past ~150
  lines, since that's usually where a procedural skill starts accumulating
  hand-written steps a script already covers.
