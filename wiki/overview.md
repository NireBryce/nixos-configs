# Overview

## Contents

- [What this is](#what-this-is)
- [The shape of it](#the-shape-of-it)
- [What's distinctive here](#whats-distinctive-here)
- [Where to go next](#where-to-go-next)

The orientation page — read this first if you don't yet know what you're
looking for. [README.md](README.md) is the index once you do; this page is
the 2-minute mental model that makes the index make sense. Like the rest of
this wiki, it's short on its own facts and long on pointers — a checkable
claim (a host count, a category list) belongs on the page that owns it, not
copied here to drift.

## What this is

A single flake-parts flake that builds NixOS (and one nix-darwin) config for
a small personal fleet — not a generalist template, and not meant to be
installed as-is (see [../README.md](../README.md)'s own warning: two hosts
wipe `/root` on every boot). One repo, one flake, every host's config comes
out of it. [hosts.md](hosts.md) has the current roster and what's actually
been switched versus only evaluated.

## The shape of it

- **A module is just a file.** `flake.nix` imports every `.nix` file under
  `flake/modules/` automatically (`import-tree`); each declares one
  `flake.modules.<class>.<name>`. No central list of modules to keep in
  sync — [architecture.md](architecture.md) has the mechanism.
- **Which category a module belongs to is decided by its directory, not a
  declaration.** A category is a directory that opts something shared
  (system config, a package, a piece of Home Manager) into being optional
  per-host. [categories/README.md](categories/README.md) is one article per
  category; [architecture.md](architecture.md) explains the mechanism itself.
- **Home Manager rides inside NixOS**, not as a separate tool with its own
  switch command — one `just switch` applies both. See
  [architecture.md](architecture.md)'s Home Manager section.
- **One host, `nire-cube`, also runs a small self-hosted stack** — a git
  forge, monitoring, a shortlink service, a landing page, backups — behind
  one reverse proxy, reachable only over Tailscale.
  [categories/homelab.md](categories/homelab.md) is the umbrella category;
  [homelab/README.md](homelab/README.md) is how to actually use what's
  running, as opposed to how it's built.

## What's distinctive here

- **Impermanence.** Some hosts in this repo wipe `/root` back to blank on
  every boot — anything not explicitly persisted is gone at the next
  reboot. Which ones is not something to assume either way — see
  [impermanence-and-secrets.md](impermanence-and-secrets.md) for the
  cross-cutting version of this, and `../CLAUDE.md`'s Safety section
  before touching anything near it.
- **Secrets are sops-nix, committed encrypted on purpose** — `secrets.yaml`
  in the repo is ciphertext, not a leak to fix. Same page as above.
- **Two tiers, not one, for anything self-hosted.** A `categories/` page is
  *configuration* — what's in it, how it's wired, what broke building it. A
  `homelab/` page is *usage* — what to actually do with the running
  service. They go stale on different triggers (a config change vs. the
  service itself changing), which is why they're kept apart rather than
  combined. [homelab/README.md](homelab/README.md) has the full reasoning.
- **This wiki, `AGENTS.md`, and the `.claude/skills/` are working notes as
  much as documentation** — written for an agent with no memory between
  sessions as much as for a human. [traps-and-skills.md](traps-and-skills.md)
  is the short version of why that shapes how things are written here.

## Where to go next

- Already know what you're trying to do → [README.md](README.md)'s Common
  tasks table.
- Want the full map of pages → [README.md](README.md)'s Pages section.
- About to touch impermanence, secrets, or anything host-hardware-shaped →
  `../CLAUDE.md`'s Safety section, read cold, before anything else.
