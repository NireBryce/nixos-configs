# 49. A freeform `settings.*` option renders unknown keys verbatim — eval passing is not evidence a setting is consumed

_Last modified: 2026-09-14_

§49 of [lessons-learned.md](../lessons-learned.md) — that page keeps the
one-line version of every lesson; this is §49's full account.

## What happened

2026-09-14, reviewing `config-system/system/security/yubikey.nix` on
`nire-tenacity`. The module set `security.pam.u2f.settings.authFile` —
camelCase — and YubiKey login worked, so the setting looked live. It was
dead: nixpkgs had renamed the option to `settings.authfile` (lowercase, via
`mkRenamedOptionModule` in `nixos/modules/security/pam.nix`), and the
rendered PAM line on the deployed host read

```
auth sufficient …/pam_u2f.so authFile=/home/elly/.config/Yubico/u2f_keys cue
```

`authFile=` is not a pam_u2f argument. The module had carried the dead key
since at least April 2026, through every rebuild and switch in between.

The same review produced two more findings, both the live system correcting
an assumption the docs-and-module reading had planted:

- The module's explicit `services.login.u2fAuth` / `services.sudo.u2fAuth`
  were restatements, not opt-ins: every PAM service's `u2fAuth` **defaults
  to** `security.pam.u2f.enable` (`pam.nix`, per-service option default), so
  `enable = true` had u2f on kde, polkit-1, sshd and passwd too — confirmed
  by grepping the live `/etc/pam.d/*`, where all of them carry the line. My
  first proposal ("add u2f to the KDE lock screen") was proposing what was
  already running.
- A drafted wake-on-insert script picked "the first session reporting
  `State=active`". The live `loginctl list-sessions` had *two* of elly's
  sessions active — the graphical one, and an unseated `class=manager`
  session that sorted first and cannot be foregrounded. Running the
  resolution logic against the machine caught it before shipping; the fix
  filters on the session having a seat.

## The mechanism

Three independent facts have to line up for a dead setting to survive five
months, and each is ordinary on its own:

1. **Freeform options accept any key.** `security.pam.u2f.settings` is a
   submodule with `freeformType = attrsOf (nullOr (oneOf [bool str int
   pathInStore]))`. The declared option is `authfile`; `authFile` lands in
   the freeform bag and is rendered verbatim as a module argument. The eval
   cannot warn — accepting unknown keys is what freeform means.
2. **The consumer discards unknown arguments.** pam_u2f 1.4.0's parser
   (`cfg.c`) falls through to a final `else cfg_load_arg_debug(cfg, arg)`
   for anything it doesn't recognize; unrecognized args are dropped, not
   errors. `cfg->auth_file` stayed null, so pam_u2f used its built-in
   default — `$XDG_CONFIG_HOME/Yubico/u2f_keys`.
3. **The default equaled the intended value.** The explicit path was
   `/home/elly/.config/Yubico/u2f_keys`; the default resolves to the same
   file. The setting was cosmetically live, functionally inert. Move the
   file — to `/persist`, or a centralized `/etc/u2f-mappings` — and the
   change would have silently done nothing.

## Why nothing caught it

No eval error (fact 1), no type error (freeform is untyped by design), no
checker (`just` has none over rendered PAM output), and the fingerprint
tools sample attributes elsewhere — `just diff HEAD` correctly said "the
change is real but outside what host-fingerprint.nix samples" when the
fix landed. §33 already records the write-time defence: the
`mkRenamedOptionModule` block at the top of a nixpkgs module is a changelog
of exactly the options a stale config will tell you to set, and this rename
is in it. What §33 does not cover is the audit half — for settings already
written, **the rendered artifact is the only place a dead key is visible**.
Read the file the consumer actually receives: `/etc/pam.d/<service>` on the
host, or eval `config.security.pam.services.<name>.text` before switching.

The u2f-everywhere discovery is §33's other half arriving by the same door
("config that agrees with the default is not harmless, because it reads as
a decision"): the explicit per-service lines implied per-service scope that
never existed, and the live files corrected it in one grep. And the
two-active-sessions miss is §24 one more time — the machine's session table
beat an assumption that felt safe because it usually holds.

## The general shape

- **Eval passing is a claim about the type, not about the consumer.** For
  any option whose value is forwarded as text — freeform `settings`,
  generated config files, command lines — the verification is reading the
  rendered output, not a clean eval.
- **A setting that works can still be dead**, when its value coincides with
  the consumer's default. The test that would have caught it is not "does
  login work" but "does the rendered config carry the key". Suspicion
  trigger: a settings block whose values you cannot distinguish from the
  defaults.
- **Read the rendered/live state before proposing behavior changes** built
  from option docs — it corrected this session's own first proposal, and it
  broke the wake script's first draft. Both before anything shipped.

## See also

- §33 — the write-time half: read the nixpkgs module (its rename block is a
  changelog), and restating a default reads as a decision.
- §24, §2 — compare against what is deployed; the repo is not the machine.
- §43, §47 — more checks that pass without proving what they seem to prove;
  §47's Caddyfile is the same "valid generated config, wrong meaning" shape.
- `config-system/system/security/yubikey.nix` — the fix, the module comment
  on `authfile`, and the history section recording what was dead.
