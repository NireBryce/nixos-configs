---
paths:
  - "flake/modules/general-config/system/secrets/**"
---

# Secrets (sops-nix)

- `secrets.yaml` here is encrypted and committed; that is deliberate, not a
  mistake to be "fixed".
- `.sops.yaml` (same directory) enrolls `nire-durandal`, `nire-lysithea`,
  `nire-tenacity`, and `nire-cube` — all live hosts with current config
  here, not a leftover to prune. `just wiki-lint` checks that list against
  `.sops.yaml`.
- "Which secrets exist?" is `just read-sops-names`: it reads the committed
  ciphertext, names only, and cannot print a value.
- `sops -d` prints every secret in the file. Never run it into the
  conversation or pipe it through anything, and never count `2>/dev/null`
  as protection: that is stderr, stdout still flows. Answering "which
  secrets exist?" by decrypting has leaked values here twice. Everything
  else about sops output: skill `secrets-hygiene`.
- `low-side/` is keyed to a personal SSH key, not host keys: skill
  `low-side-secrets`.
