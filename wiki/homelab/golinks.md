# Creating go/ links

## Contents

- [Where it is](#where-it-is)
- [Creating a link](#creating-a-link)
- [Paths after the short name get appended](#paths-after-the-short-name-get-appended)
- [Advanced destinations are Go templates](#advanced-destinations-are-go-templates)
- [Reading links back](#reading-links-back)
- [Traps](#traps)
- [Backups](#backups)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

`go/foo` shortlinks, served by [golink](https://github.com/tailscale/golink)
on `nire-cube`. This page is about **using** it. For how it's configured,
why it needed an `AF_NETLINK` fix, and why it's a tailnet device rather than
a port on cube — see [shortlinks](../categories/shortlinks.md).

## Where it is

| | |
|---|---|
| From any tailnet device | `http://go/` |
| Canonical (HTTPS) | `https://go.<tailnet>.ts.net/` |
| Live help, from upstream | `http://go/.help` |

`http://go/` **302s to the HTTPS name** — this tailnet has HTTPS enabled, so
golink redirects everything to its cert domain before resolving. That's not
a misconfiguration; it's golink's `redirectHandler`, and it's the source of
the `curl` trap below.

golink runs as its own tailnet device named `go`, not as a service on cube's
address. If `go/` stops resolving, check the device is still up in the admin
console before suspecting cube — and don't rename it, because the name *is*
the feature.

## Creating a link

**The web UI is the normal path.** Open `http://go/`, type a short name and
a destination, hit Create. Editing and deleting are on each link's own page.

From the command line:

```sh
curl -L --post302 -H Sec-Golink:1 \
  -d short=cs -d long=https://cs.github.com/ \
  http://go/
```

Three things in that line are load-bearing:

- **`-L`** — follows the HTTPS redirect. Without it you get the redirect
  stub, not your data. See the trap section.
- **`--post302`** — re-sends the POST body across that redirect. `-L` alone
  turns a 302 into a GET and silently drops the form fields.
- **`-H Sec-Golink:1`** — golink's XSRF bypass for non-browser clients. It's
  a header browsers can't set from JavaScript (per the Fetch spec), which is
  what makes it safe to accept as proof the request isn't a cross-site
  forgery.

Short-name rules, from golink's own help page:

- must start with a letter or number
- may contain letters, numbers, hyphens and periods
- **not case-sensitive** — `go/Foo` is `go/foo`
- **hyphens are ignored when resolving** — `go/meetingnotes` and
  `go/meeting-notes` are the same link

## Paths after the short name get appended

If `go/who` points at `http://directory/`, then `go/who/amelie` goes to
`http://directory/amelie`. That's the default with no extra work, and it's
usually all you need.

## Advanced destinations are Go templates

To put the path somewhere other than the end, the destination can be a Go
template. It's given:

| field | is |
|---|---|
| `.Path` | everything after the short name, no leading slash |
| `.Now` | a `time.Time` for right now |
| `.User` | the resolving user's email (or `{username}@github`) |

plus the functions `PathEscape`, `QueryEscape`, `TrimPrefix`, `TrimSuffix`,
`ToLower`, `ToUpper` and `Match`.

```
go/search  →  https://www.google.com/{{if .Path}}search?q={{QueryEscape .Path}}{{end}}
go/slack   →  https://company.slack.com/{{if .Path}}channels/{{PathEscape .Path}}{{end}}
go/varz    →  http://{{if .Path}}{{.Path}}{{else}}host{{end}}.example/debug/varz
go/today   →  http://wiki/{{.Now.Format "01-02-2006"}}
```

The `{{if .Path}}…{{end}}` wrapper is the pattern worth copying: it makes
the bare `go/search` land somewhere sensible instead of on a malformed URL.

## Reading links back

```sh
curl -L http://go/search+      # one link's metadata as JSON, without resolving it
curl -L http://go/.export      # every link, JSON Lines
```

`go/.all` lists everything in the browser, and `go/.export-stats` has click
counts.

## Traps

**`curl` without `-L` looks like an empty or broken response.** You get the
302 and its one-line `<a href="…">Found</a>.` body instead of your JSON.
Upstream recommends `-L` on *every* golink deployment regardless of whether
HTTPS is on yet, so a later flip doesn't quietly break your scripts. Verified
here 2026-08-24: `curl -sL http://go/.export` returns cleanly; the same
command without `-L` returns the redirect stub.

**Deleting from the command line has never worked.** `serveDelete` always
requires a browser XSRF token, and the `Sec-Golink` header does *not* satisfy
it — only create/update accept that bypass. There's a comment in golink's own
source saying so, and calling it the deliberate status quo rather than an
oversight. **Delete through the web UI.** This is also why nothing was
created as a probe while writing this page: a curl-created test link couldn't
have been cleaned up the same way.

**Ownership is per-user.** You own what you create and only you can edit or
delete it; ownership can be handed over from the link's edit page. Links
owned by someone no longer on the tailnet become editable by anyone, who then
becomes the owner. Tailnet-wide admin rights are an ACL grant
(`tailscale.com/cap/golink`), set in the admin console, not here.

**Firefox treats `go/` as a search.** Fix it in `about:config`: add a boolean
`browser.fixup.domainwhitelist.go` set to `true`. If you use HTTPS-Only Mode,
add an exception too.

## Backups

`http://go/.export` is the whole database as JSON Lines. golink can restore
from one (`-snapshot links.json`, which only adds links that don't already
exist) and can resolve against one offline
(`-resolve-from-backup links.json go/foo`).

**Nothing in this repo automates that.** No timer, no export job, no
committed snapshot — and because `nire-cube` has a plain persistent root
rather than the `/root` wipe, the database survives reboots on its own, so
there's no forcing function that would make its absence obvious. If the links
ever become load-bearing, this is the gap.

## What's verified here

Exercised against the live instance on 2026-08-24, from `nire-lysithea` over
the tailnet: `http://go/` (302 → HTTPS, then `HTTP 200`, `<title>go/</title>`),
`go/.help` (`HTTP 200`), `go/.export` (clean, and empty — the instance was
new), and the with/without-`-L` difference.

**Not exercised:** creating, editing or deleting a link, and the template
examples. Those are from golink's own help page and source at the pinned
revision, not from a run here — see the delete trap above for why nothing was
created to test with. `http://go/.help` is the live, canonical version of all
of it, and it will be right about the running build even when this page has
drifted.

## See also

- [shortlinks](../categories/shortlinks.md) — the module, the `AF_NETLINK`
  first-switch failure, and why golink is its own tailnet device.
- [homelab README](README.md) — the other services on this tailnet.
- [hosts.md](../hosts.md) — `nire-cube`, which runs it.
