# list-unrequested-choices

- **Source:** `AGENTS.md`, "Before calling it done" (the paragraph "List the choices you made that the user did not ask for")
- **General kernel:** an agent ends each task report with a short list of the decisions the request did not dictate (a default picked, scope added or dropped, a behavior unlike the obvious one), one line each with how to reverse it, leaves out anything the repo's instructions already settle but lists a departure from a documented default, and omits the list when there were none or the reply changed nothing, so the user can object to a decision they never saw and the diff does not have to show which parts were judgment calls.
- **Strip/replace:** the section name in `AGENTS.md`; the clause "this file, a rule file or a skill" points at this repo's own rules.
- **Evidence:** none yet; added 2026-11-15 at the user's request after the pattern was used by hand in one session.
- **Depends on:** none.
- **Recorded:** 2026-11-15
