---
paths:
  - "flake/modules/general-config/homelab/**"
  - "flake/modules/host-config/cube/**"
---

# Homelab services

- Adding a service: skill `new-homelab-service`. Three of the first five
  broke on their first switch for reasons eval, build and reading the
  rendered artifact all missed; the skill's verification order is what
  they cost. A Tailscale `svc:` name is skill `new-tailscale-service`.
- `general-config/homelab/` is an umbrella category nesting several
  cube-only categories, the same coarse-and-fine overlap as
  `general-config/hardware` / `general-config/hardware/amd`. Nested
  category names and a real collector quirk: `wiki/categories/homelab.md`.
