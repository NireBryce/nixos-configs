# 0. What this section is for

_Last modified: 2026-10-27_

A note for a person reading this folder. The numbered files here (`1-*.md`
and up) are written for the coding agents that work on this repo, not for
you, so they read oddly if you open one cold. This page says why they exist.

## What the lessons are

Each file is the full account of one mistake an agent made in this repo, or
nearly made, and the rule that came out of it. The accounts are in the first
person, and the "I" is a machine. The agents that make these mistakes have no
memory between sessions, so the one that gets a lesson wrong today knows
nothing about the session that wrote it up last month. Writing it down is the
only way the next session finds out.

The accounts say what was believed, what was actually true, how it was found,
and what to do instead. They keep the specifics (the host, the command, the
wrong assumption) because a bare rule like "verify your changes" has never
stopped anyone, and a story about the time it went wrong at least gives an
agent something to recognize.

## Why they're kept apart from the rules

[`AGENTS.md`](../../AGENTS.md) is the short list of rules every session loads.
It can't carry the history behind each one without becoming too long to read
every time. So the rule lives there (or in a skill, or a path-scoped rule
file), and the story lives here. The two point at each other: the index page,
[`agent-lessons-learned.md`](../agent-lessons-learned.md), files each lesson
by the moment it applies, and names for each one:

- its **Home**, the place an agent doing that task is already reading, where
  the rule is stated;
- what **Enforced** it, meaning a check or hook that fails or warns, or `none`
  if the rule only exists as text.

`none` is an honest answer, and it marks a candidate for a check. A lesson
that only a reader can apply is the weakest kind.

## How they get used

Agents don't read this folder front to back. A hook looks at what a session
is about to edit or run and puts the matching one-line reminders in front of
it, using the topic map in
[`.agents/lessons-map.toml`](../../.agents/lessons-map.toml). `just agent
lessons <path>` prints the ones that apply to a file or area. The full
account is for when a reminder isn't enough, or when someone wants to know
why a rule is shaped the way it is.

## If you're a person

- To see what has gone wrong here, read the index page. It's grouped by task,
  one line per lesson.
- To judge whether a rule in `AGENTS.md` still earns its place, open its
  account and see what it was reacting to.
- To add one, follow the "Adding one" steps on the index page. The numbers are
  stable and cited across the repo, so never renumber them.
- If an account is wrong or out of date, correct the account. Don't add a
  second one that contradicts it.

The first-person voice is deliberate. These are an agent's notes to its later
selves, not documentation, and nobody has tidied them into something else.
