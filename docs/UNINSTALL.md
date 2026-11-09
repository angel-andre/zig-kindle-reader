# Uninstall, rollback and recovery

## Recover before uninstalling

From a working SSH connection, on the Kindle:

```sh
sh /mnt/us/zreader/zreader-maintenance.sh restore-ui
```

This terminates the reader, resumes the four paused UI processes, clears its screensaver inhibitor and requests the normal interface. If genuinely suspended, press power once to regain access. Check the display; the command is a best-effort recovery request, not a hardware guarantee.

## Preserve your data

Copy `/mnt/us/zreader/state`, `notes`, `export`, `settings.json`, `ui07.json` and `last_book` to your computer before uninstalling. If you used Shrink for Kindle, `originals/` holds the original PDFs; copy them too if you want them back. Back up books separately. Do not delete `/mnt/us/Books`.

If you used the crash-dump helper and want to undo its marker, run `undo-core-dumps` before moving the installation. If the helper refuses ownership, stop and inspect; do not force-remove a marker that might predate the reader.

## Reversible removal

After restoring the UI and closing all readers, rename `/mnt/us/extensions/zreader` and `/mnt/us/zreader` to unused backup names outside the active extension location. Do not overwrite existing backup directories. KUAL may need reopening to refresh its menu. Keep those backups until your notes are safely copied off-device; then remove only those identified reader directories if desired.

No package manager, rootfs cleanup, service deletion or jailbreak reversal is required. This does not uninstall KOReader or KUAL and does not change your SSH configuration. Dropbear started for recovery can remain running; manage it using your existing SSH setup, not by deleting its files.

## Rollback

Restore your saved previous executable, launcher and KUAL extension while closed. The previous release, 0.12.3, is kept as `release/zr123.tgz` (install it exactly like 0.12.4; `zreader --version` then prints `zreader 0.12.3`). Preserve newer notes/state first; older versions may not understand every new field or anchor format. For an exact rollback, restore a matched older runtime and its corresponding backed-up user data. Do not overwrite your only copy of newer notes. Reopen and verify the expected version.

Removing the reader cannot restore deleted crash dumps or VoiceView files. Those require a backup; VoiceView reinstallation is firmware-dependent and was not validated in this project.
