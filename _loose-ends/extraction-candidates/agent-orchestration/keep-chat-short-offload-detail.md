# keep-chat-short-offload-detail

_Last modified: 2026-11-15_

- **Source:** `AGENTS.md`, "Write plainly" (the bullet "Keep chat replies short and put long detail where it isn't re-read")
- **General kernel:** everything an agent writes in chat is re-read on every later call, so keep replies short, put long detail in a PR body, a doc or a file, and after a very large turn (a long audit, a big diff, a long command log) have a cheaper-model subagent read the output and return the summary, checking any claim acted on against the source; the judgment-heavy part of a report is not delegated.
- **Strip/replace:** the `model: "haiku"` parameter (use whichever cheap model the harness offers), the cross-reference to the choices list.
- **Evidence:** a 7-day measurement of this repo's session transcripts (2026-11-15): tool results were about 27% of re-read tokens, and three sessions of 250 to 414 calls made up 70% of all calls. The rule itself has no enforcing check and has not been used yet.
- **Depends on:** `list-unrequested-choices` (the exclusion) is optional.
- **Recorded:** 2026-11-15
