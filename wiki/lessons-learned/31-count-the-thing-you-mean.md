# 31. Count the thing you mean, and check the cleaner before declaring there is none

_Last modified: 2026-09-29_

§31 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §31's full account.

Found `/var/lib/systemd/coredump` at 1.1G and wrote a module capping it, on the
reasoning that "nothing ever clears it" and "the store only ever grows". Both
false, and the machine was right there to say so:

- systemd ships `d /var/lib/systemd/coredump 0755 root root 2w` in tmpfiles, and
  `systemd-tmpfiles-clean.timer` runs it daily. It had run ten minutes earlier.
- **Zero** files were older than fourteen days. Retention was working exactly as
  designed.

The second error was reading a number from the wrong tool. `coredumpctl list`
reported 76,171 entries; `find -type f` reported 1121 files. Those count
different things — the journal keeps a record after tmpfiles has vacuumed the
dump — so the "backlog" I thought was being reprocessed every boot was mostly
records whose files were already gone. drkonqi's "Unable to find file for pid
… expected at kcrash-metadata/…" is that, and is normal.

§22 is about not believing a zero without showing the query can return non-zero.
This is the same error with a large number: **a count is only evidence if you
know what it counts.** `coredumpctl list | wc -l` and `find | wc -l` differ by
70x here and neither is wrong.

The module survived, with its justification replaced. It is a rate ceiling —
bounding what a crash loop can spend between daily cleanups — not the retention
policy it claimed to be. And the cap was initially set *below* the 1.1G a real
bad fortnight had just produced, which would have discarded dumps during exactly
the incident they were wanted for. **A limit under the observed worst case is
not a safety measure.**
