# Tenacity: SD card reader intermittently fails to enumerate

_Last modified: 2026-10-21_

On `nire-tenacity`, the internal SD card reader stopped coming up on some
boots and resumes after the jump from Linux 6.18.55 to 6.18.57. While it is
missing, the lock screen's YubiKey prompt is slow. **Tabled 2026-10-21**, on
the expectation that a nixpkgs kernel bump may fix it. Nothing in the config
works around it yet. Recheck after the next kernel bump on tenacity: the
same bump that makes `no-tiny-power-button.nix` warn
([temporary-patches-and-hacks.md](../temporary-patches-and-hacks.md)).

## Contents

- [Symptom](#symptom)
- [Evidence](#evidence)
- [Ruled out](#ruled-out)
- [Suspected cause](#suspected-cause)
- [Next test](#next-test)
- [Stopgap](#stopgap)

## Symptom

The reader is a Genesys Logic `05e3:0764` ("USB Storage") on USB3 root
port `2-1` of xHCI `0000:c3:00.3`. When it fails:

```
xhci_hcd 0000:c3:00.3: Timeout while waiting for setup device command
usb 2-1: device not accepting address N, error -62
usb usb2-port1: unable to enumerate USB device
```

The kernel retries for about 45 s: four address attempts plus one port
power cycle. The loop runs at boot and again after every resume while the
reader is missing. The card never appears as a block device.

**The slow FIDO prompt is a side effect.** The YubiKey (`1-2`, `1050:0406`)
is on the same controller and autosuspends after 2 s. While the retry loop
holds the controller, the lock screen's `pam_u2f` prompt comes up late. On
2026-10-21, kscreenlocker's worker started 12.8 s after the greeter (1.6 s
on a good boot). The greeter also logged `Received prompt response, but no
pending prompt` 5 and 15 s after a wake. SDDM login doesn't show it,
because the boot-time loop finishes before the user reaches the prompt. On
wakes where the reader enumerated (20:04 and 20:19 that day), the prompt
was immediate and no xHCI timeouts were logged.

## Evidence

Reader state per boot, from `journalctl -b <n> -k -g 'usb 2-1'`:

| kernel | boots | reader enumerated |
|---|---|---|
| 6.18.43, .53, .55 | 5 | 5 of 5 (one boot had 10 resumes with no reader errors) |
| 6.18.57 | 11 | 6 of 11 |

- **Recovers on its own.** After failing on every resume in one boot, it
  came back on a later resume with nothing changed.
- **Fails without system suspend.** In one 6.18.57 boot it enumerated at
  boot (card visible as `sda`), went quiet for 47 s, then failed
  re-addressing and disconnected.
- The reader's own `power/control` is `on`, so it doesn't autosuspend.
  The `usb2` root hub's is `auto`.

## Ruled out

- **The system generation.** Two consecutive boots on the identical system
  and kernel build (`jz29q…`) differed: one worked, one didn't.
- **A power-off during resume.** Before the `tiny_power_button` blacklist,
  a power-button wake signalled init to power off mid-resume. One boot
  ended that way and the next boot's reader worked.
- **6.18.57 itself.** Its changelog has no xHCI, USB core, hub or
  usb-storage commits.
- **A partial backport like the power-button one.** See the candidate
  below.

## Suspected cause

Unconfirmed. 6.18.56 carries `usb: hub: use shorter 120ms post resume hold
for SS root hubs` (upstream `29480b05e6e2`, stable `e9545dd8bc62`). It cuts
a USB3 root hub's post-resume runtime-PM hold from 200 ms to 120 ms, and was
written for an AMD platform issue. Its own message says a root hub "still
need[s] some time for USB3 link training to complete". With the reader
missing, the `usb2` root hub has nothing attached and keeps suspending and
resuming, so it goes through this path repeatedly.

It is a complete backport. v1 was patch 1/2. Patch 2/2 (`xhci: drop 120ms
U3 LFPS wake retry wait from runtime resume`) was dropped on purpose by the
xHCI maintainer, and v2 is a standalone patch. No reports of enumeration
failures against it were found.

- [v2 patch](https://ratatoskr.run/lkml/2026/09/17504293/t)
- [v1 series and the 2/2 discussion](https://ratatoskr.run/regressions/2026/08/17487335/t)
- [ChangeLog-6.18.56](https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.18.56),
  [ChangeLog-6.18.57](https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.18.57)

## Next test

Run this while the reader is missing (check with `journalctl -b -k -g 'usb
2-1: device not accepting'`). It lasts until reboot:

```sh
echo on | sudo tee /sys/bus/usb/devices/usb2/power/control
echo 0 | sudo tee /sys/bus/usb/devices/usb2/authorized
echo 1 | sudo tee /sys/bus/usb/devices/usb2/authorized
journalctl -k -g 'usb 2-1'
```

- **`New USB device found, idVendor=05e3` appears at once:** root-hub
  runtime PM is implicated. The fix is a udev rule setting
  `power/control=on` for `usb2` under `0000:c3:00.3`, listed in
  [temporary-patches-and-hacks.md](../temporary-patches-and-hacks.md). It
  also removes the lock-screen delay, since no retry loop would run on
  resume.
- **It doesn't:** boot a 6.18.55 generation (95–98 on tenacity) several
  times. At about 50 % failure on 6.18.57, one good boot proves nothing.

## Stopgap

(Opening the card in a file manager or KDE Partition Manager doesn't
bring the reader back; they only list what the kernel has already
detected. On 2026-10-21 it looked that way: Dolphin was opened at
19:42:45, 10 s after the kernel gave up, and stayed open until 20:30. The
kernel logged nothing for the reader until the 20:04:17 wake, then
detected it 110 ms later. A resume is the only thing so far that has made
the kernel retry once it has given up.)

For the lock-screen delay only, this stops the retry loop until reboot. It
also disables the reader:

```sh
echo 1 | sudo tee /sys/bus/usb/devices/usb2/2-0:1.0/usb2-port1/disable
```
