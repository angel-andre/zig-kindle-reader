# Safe cleanup: what actually changed

This describes what was done on our Kindle Paperwhite 12th gen; it is not a “debloat everything” script. The user partition `/mnt/us` is separate from the small system partitions. **No system partitions were modified or cleaned.** No permanent removal of Amazon services was performed.

| Change | Scope and observed result | Reversal |
| --- | --- | --- |
| Removed accumulated `KPPMainAppV2_*.core` crash dumps and identified crash `.tgz` archives in `documents/` | About 2.5 GB recovered | Only a saved backup can restore deleted diagnostics |
| Removed `/mnt/us/voice` VoiceView voice data | About 150 MB recovered; removes the local speech payload | Restore your backup or follow the official device/firmware VoiceView voice-install procedure (not tested here) |
| Cleaned identified old reader-install leftovers from temporary storage | Resolved a later installation's “no space” failure; exact reclaimed bytes not recorded | None needed |
| Switched future install staging to `/mnt/us` | Avoids filling the small temporary filesystem | No rollback needed |
| Created the `/mnt/us/DISABLE_CORE_DUMP` marker to stop new crash dumps | Prevents crash dumps from filling storage again | `sh /mnt/us/zreader/zreader-maintenance.sh undo-core-dumps` |

After cleanup, about **9.2 GB free** was reported on the roughly 11.5 GB user partition. Books remained intact. Figures are approximate.

## Reproducing safely

1. Quit readers and back up user storage first. Inspect `df -k /mnt/us` and `df -k /tmp` separately.
2. List candidate crash files, check names and sizes, and save any diagnostics you need. A `.tgz` extension alone does **not** make a file safe to delete; it might be your backup or installation package.
3. Remove only individually confirmed crash files. This repository intentionally supplies no recursive wildcard delete command.
4. Do not remove `/mnt/us/voice` if you need VoiceView accessibility. Make an off-device copy first if you want a reliable undo.
5. Inspect free space again. Never chase system-partition usage by deleting `/`, `/var/base-local`, libraries, startup jobs, jailbreak files or OTA-related files.

Do not assume that every matching filename or all of `documents/` is expendable.

## Reversible crash-dump marker

Run on the Kindle, after installation:

```sh
sh /mnt/us/zreader/zreader-maintenance.sh status
sh /mnt/us/zreader/zreader-maintenance.sh disable-core-dumps
# Undo later:
sh /mnt/us/zreader/zreader-maintenance.sh undo-core-dumps
```

The helper creates an empty `/mnt/us/DISABLE_CORE_DUMP` and an ownership receipt. It preserves pre-existing markers and refuses to remove a changed/replaced/nonempty/symlink marker. Identity changes after remount/reboot may cause undo to refuse; inspect manually rather than force deletion. Suppression loses future diagnostic evidence and does not fix the cause of crashes. The marker's efficacy depends on firmware; no global handler/kernel/upstart inspection or forced-crash verification was performed.

On our Kindle the marker is applied. The launcher does not create it by default; run `status` to check yours.

Public references: [MIP crash-log documentation](https://mip-wiki.pages.dev/database/crashlog/), [MobileRead discussion](https://www.mobileread.com/forums/showthread.php?t=366779). These describe the mechanism; firmware behaviour may vary.

## What the launcher pauses, not removes

While reading it pauses `awesome`, `volumd`, `blanket` and `Xorg`; it does **not** pause `cvm`. It temporarily disables Pillow UI, stops an active status bar and inhibits screensaver. Exit resumes the paused processes, restores the saved framebuffer, restarts the status bar when appropriate and requests home. Emergency `restore-ui` is independent of reader responsiveness.

The launcher may start key-only Dropbear from KOReader and add connection firewall rules when needed. It intentionally leaves SSH running for recovery. These runtime actions are not permanent debloating or system-partition edits. Do not disable networking/security protections as a cleanup shortcut.
