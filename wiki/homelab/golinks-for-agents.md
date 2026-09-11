# Creating go/ links, for agents

_Last modified: 2026-09-11_

Condensed from [golinks.md](golinks.md). Config side:
[../categories/shortlinks-for-agents.md](../categories/shortlinks-for-agents.md).

`http://go/` from any tailnet device. `http://go/.help` is the canonical
upstream help, and right about the running build when this page has drifted.
**`http://go/` 302s to the HTTPS cert domain** (golink's `redirectHandler`) —
the source of the `curl` trap below.

golink is its own tailnet device named `go`; if `go/` stops resolving check
that device before suspecting cube. **The name is the feature — don't rename
it.**

## Creating a link

Web UI is the normal path. From the command line:

```sh
curl -L --post302 -H Sec-Golink:1 \
  -d short=cs -d long=https://cs.github.com/ \
  http://go/
```

All three flags are load-bearing:

- **`-L`** — follows the HTTPS redirect. Without it you get the redirect
  stub, not your data.
- **`--post302`** — re-sends the POST body across that redirect. **`-L` alone
  turns the 302 into a GET and silently drops the form fields.**
- **`-H Sec-Golink:1`** — golink's XSRF bypass for non-browser clients; a
  header JavaScript cannot set, which is what makes accepting it safe.

Short-name rules: must start with a letter or number; letters, numbers,
hyphens, periods only; **not case-sensitive**; **hyphens ignored when
resolving** (`go/meetingnotes` == `go/meeting-notes`).

## Destinations

A path after the short name is **appended** by default — `go/who` →
`http://directory/` means `go/who/amelie` → `http://directory/amelie`.

To put it elsewhere, the destination is a Go template, given `.Path`
(everything after the short name, no leading slash), `.Now` (`time.Time`),
`.User` (resolving user's email, or `{username}@github`), plus
`PathEscape`, `QueryEscape`, `TrimPrefix`, `TrimSuffix`, `ToLower`,
`ToUpper`, `Match`.

```
go/search  →  https://www.google.com/{{if .Path}}search?q={{QueryEscape .Path}}{{end}}
go/today   →  http://wiki/{{.Now.Format "01-02-2006"}}
```

**Wrap in `{{if .Path}}…{{end}}`** so the bare `go/search` lands somewhere
sensible instead of a malformed URL.

## Reading back

```sh
curl -L http://go/search+      # one link's metadata as JSON, no resolve
curl -L http://go/.export      # every link, JSON Lines
```

`go/.all` lists in the browser; `go/.export-stats` has click counts.

## Traps

- **`curl` without `-L` looks like an empty or broken response** — you get
  the 302 and a one-line `Found` body. Use `-L` unconditionally, so a later
  HTTPS flip doesn't break scripts.
- **Deleting from the command line has never worked.** `serveDelete` always
  requires a browser XSRF token; `Sec-Golink` does **not** satisfy it — only
  create/update accept that bypass, deliberately per upstream's source.
  **Delete through the web UI.**
- **Ownership is per-user** — you can only edit or delete what you created;
  hand it over from the link's edit page. A link owned by someone off the
  tailnet becomes editable by anyone, who then owns it. Tailnet-wide admin is
  an ACL grant (`tailscale.com/cap/golink`), in the admin console.
- **Firefox treats `go/` as a search.** `about:config` → add boolean
  `browser.fixup.domainwhitelist.go` = `true`. Add an HTTPS-Only Mode
  exception too.

## Backups

`http://go/.export` is the whole database as JSON Lines; golink restores from
one (`-snapshot links.json`, adds only links that don't exist) and can
resolve offline against one (`-resolve-from-backup links.json go/foo`).

**Nothing in this repo automates that** — no timer, no export job, no
committed snapshot. Cube's persistent root means the db survives reboots, so
nothing forces the gap into view.

**Not exercised**: creating, editing, deleting a link, and the templates —
from upstream's help page and source at the pinned revision, not a run here.

## See also

[golinks.md](golinks.md) ·
[../categories/shortlinks-for-agents.md](../categories/shortlinks-for-agents.md)
