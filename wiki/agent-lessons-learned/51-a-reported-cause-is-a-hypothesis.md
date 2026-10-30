# 51. A reported cause is a hypothesis until the code agrees

_Last modified: 2026-10-30_

## Index entry

§51 in [agent-lessons-learned.md](../agent-lessons-learned.md)

## The lesson

Three times in one session a stated cause was wrong, and each was caught only
because the code was read before the claim went into an issue or a status
comment:

1. A worker that ran polymorph's discovery against OpenCode reported that every
   payload was grouped as `<invalid>` because "polymorph evidently resolves the
   event name under a different key". The key was fine. The event-name check
   allowed only letters, digits and underscores, and `execute.before` has a dot.
   The suggested fix (`--event-key`) would have added an option and left the bug.
2. The same report said `grep` was "mis-classed under `read`". In this repo's
   own canonical classes Claude's Grep and Glob are `read`; there is no search
   class, so the behaviour was right.
3. The assistant itself told the user the draft `gemini` mapping lacked a
   post-call event. The mapping has `post_tool = "AfterTool"`; its real gaps
   were the `mcp`/`other` tools and the `read.*` fields. A worker's end-to-end
   run found it.

All three were plausible, specific, and delivered in the confident voice of a
finding. Nothing in the text said "guess".

## The rule

A cause that comes from a report, a worker, a search result or your own memory
is a hypothesis. Before it goes into an issue, a comment or a status line as
fact, read the code or run the reproduction that would show it, and say which
you did. If you didn't, write it as "likely" and say what would confirm it.
Quote what you read (the regex, the table entry), not what you concluded.

## Related

§3 (when a tool contradicts you, check your own assumption), §22 (before
believing a zero, show the query can return non-zero).
