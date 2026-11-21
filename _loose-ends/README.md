# `_loose-ends/`

`_loose-ends/` holds material that waits on a later action outside the normal
build-and-ship flow: a filing only the user may make, a pattern to extract, a
removed module to restore, a review, a cleanup on live hosts. Nothing here is
imported, built or linted as config. Each item ends when its action happens.

## Does it belong here

Put it where the first matching line says:

- It states how the config works now: the wiki.
- It is a procedure an agent repeats: a skill.
- It is a defect in this repo that someone should fix: a GitHub issue in
  `NireBryce/nixos-configs` (skill `propose-issue`).
- It runs: code, under `flake/` or `.agents/`.
- It is held for a later action and gets deleted or moved when that action
  happens: here, in the folder whose shape fits.

Security or threat analysis goes in the private `elly/infra-notes` repo, never
here: this folder is public.

## Shapes

| Folder | What goes in | Name | Must carry | Owner | Ends when |
| --- | --- | --- | --- | --- | --- |
| `bugs-pending-submission/` | A paste-ready bug report against another project | `YYYY-MM-DD-bugreport-<slug>.md` | Title naming the project; a "Written YYYY-MM-DD against `<rev>`" line; the target tracker URL; the "Not filed" banner; the report under "Describe the bug"; a closing "Local notes — remove before filing" section; a tracking `upstream` issue here | Agents write it; only the user files it, report by report | The user files it or upstream fixes it. Delete the file and fix the backticked paths that cite it in `wiki/` in the same change |
| `extraction-candidates/agent-orchestration/`, `extraction-candidates/nix/` | A mechanism here that would work in another repo | `<short-name>.md`, named for the mechanism | The fields in skill `extract-agent-tooling`, "File shape", including **Recorded:** | Skills `extract-agent-tooling`, `extract-nix-tooling` and their `-all` sweeps; nothing is copied out unless the user asks | The candidate is extracted or fails the generality test |
| `reports/` | A working document that asks the user for a review | `<topic>.md` | A `_Status:_` line with the date written, who wrote it and what is left | The user reviews | The review is done: trim it to the record worth keeping, or delete it |
| `shelved/` | A module file removed from the config with intent to restore | A folder `shelved/<module-name>/` holding the files as they were at removal | `README.md` with the shelved date in the title, what it did, why it was removed, the rung it last reached, and numbered restore steps; a comment in each module that referenced it pointing here | The user decides | It is restored with `git mv`, or the user drops it |
| `nire-fleet/` (new) | Operational follow-ups for the fleet that span PRs or hosts and end in deleting the note | `<short-name>.md` | `_Last modified: YYYY-MM-DD_`; an opening line saying when to delete it; "What it is"; "State as of YYYY-MM-DD"; a numbered "To do" whose last step is deleting the file; "Related" paths | Agents keep it current; the user runs steps an agent cannot | The last step runs and the file is deleted |

Files outside `flake/modules/` are not read by dirs-as-categories, so a `.nix`
file in `shelved/` stays inert until moved back.

Earlier practice never wrote down when a bug report or a `reports/` file is
removed. The "Ends when" column states the rule from here on. `nire-fleet`
names the fleet, not a host.

## Writing a note

- Date every state claim absolutely (`as of 2026-11-21`), never "now" or
  "recently".
- Point at the file or command that holds a fact instead of copying its value.
- Refer to the person as "the user".
- A filing to another project needs the user to ask for that filing in their
  own message. A file existing here is not that request.

## Anything else

When an item fits none of the shapes above, put it in
`_loose-ends/other/YYYY-MM-DD-<short-name>.md`. It must carry:

1. A title saying what it is.
2. The absolute date written.
3. One paragraph on what it is and why it is held instead of acted on.
4. The owner (the user, an agent, or a named skill) or the next step.
5. When to delete it.

The third time a similar item lands in `other/`, give it its own folder, move
the items into it, and add a row for it to the table above in the same change.
