# 3. When a tool contradicts you, suspect yourself first

_Last modified: 2026-09-29_

§3 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §3's full account.

Twice I concluded a tool was broken and was wrong both times.

- `diff-config.sh` reported IDENTICAL against `HEAD~2`; an interleaved commit
  meant `HEAD~2` was not the commit I assumed.
- A `zsh -f -c` test appeared to show aliases do not chain. **zsh expands
  aliases at parse time**, so an alias defined and used in one command never
  could. Behind `eval`, both shells chain fine.

The second nearly cost three `eza` flags: the intuitive repair breaks the chain.
