# 22. Name matching fails silently, and reads exactly like a real negative

_Last modified: 2026-09-29_

§22 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §22's full account.

§5 records this for `home.file` names. It recurred twice in output I had
generated myself:

- **The option and the package spell it differently.** I searched a build plan
  for `acpi_call` — the spelling used by `boot.extraModulePackages` — and got
  zero hits. The package is `acpi-call`. One keystroke from reporting a module
  the TDP control depends on as missing.
- **Zero in both columns can mean "already present".** `adjustor` appeared in
  neither the build nor the fetch list because it was already in the store. A
  dry-run enumerates *work*, not contents.

Same class, caught before shipping: `modules.py`'s pattern was `\w+`, which does
not match a hyphen. **Hyphens are legal in Nix identifiers**, so it would have
read `kde-base` as `kde` and reported a module created that hour as dead.

**Before believing a zero, show that the query can return non-zero.**
