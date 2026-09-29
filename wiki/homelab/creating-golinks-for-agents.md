# Creating go/ links, for agents

_Last modified: 2026-09-29_

Condensed from [creating-golinks.md](creating-golinks.md). Config side:
[../categories/shortlinks-for-agents.md](../categories/shortlinks-for-agents.md).

`http://go/` from any tailnet device; `http://go/.help` is canonical upstream
help (right about the running build when this page drifts).
**`http://go/` 302s to the HTTPS cert domain** (`redirectHandler`).

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

- **`-L`** — follows the HTTPS redirect (else you get the stub).
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

- **`curl` without `-L` looks empty/broken** — a 302 with a one-line `Found`
  body. Always use `-L`.
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

**Nothing in this repo automates that** — no timer, export job, or committed
snapshot.

**Not exercised**: creating, editing, deleting a link, and the templates —
from upstream's help page and source at the pinned revision, not a run here.

