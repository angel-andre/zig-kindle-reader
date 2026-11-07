# Troubleshooting

## Frozen screen or stock interface not returning

Wake once if asleep, then run over SSH:

```sh
sh /mnt/us/zreader/zreader-maintenance.sh restore-ui
```

It requests reader termination, UI process resumption, Pillow/statusbar restart, powerd inhibitor clearing and stock home. Check the physical screen. If no SSH is reachable during suspend, wake first. If recovery remains impossible, use the device's documented hardware reboot; never edit system partitions or remove jailbreak/OTA markers.

## Cannot connect

Check the trusted network route and current address locally, port 2222, the intended private key and the already-provisioned authorized public key. Keep key-only authentication. Do not enable no-auth access or upload a private key to the device/repository. USBNetwork was not validated here.

## Touch does nothing

Quit KOReader first: it can hold the input grab. Do not run multiple readers concurrently. Recover the stock UI before relaunching.

## No space during install despite gigabytes free

`/tmp` and `/mnt/us` are different filesystems. Stage on `/mnt/us`, check both with `df -k`, and inspect only your known staging leftovers. Do not erase all temporary files, crash archives indiscriminately or system partitions. BusyBox `sort` on the reference device has no `-h` option.

## Book missing, cover blank or progress unexpected

Use `/mnt/us/Books` and PDF/EPUB filenames; reset Folder to All. Placeholder covers are expected for broken or too-complex documents. Cache identity includes full path, size and modification time; restart for changed books. Notes currently collide for equal basenames—use unique filenames.

## Ghosting / dark mode

Hardware dark mode is intentional and must stay unchanged. Use Refresh for a full clean or change periodic refresh to 4/8/16. Off still allows heavy/context cleans. Physical e-ink efficacy is not proved by host PNGs. Do not write framebuffer inversion flags, procfs driver settings or backlight sysfs.

## Drop-cap overlap

A supplied calibre-generated PDF already had overlapping initials/body text. Both MuPDF and Poppler showed the same issue. Use an original EPUB or correctly typeset PDF; a source-faithful renderer cannot reconstruct missing layout geometry.

## Dictionary / notes

A missing/corrupt dictionary displays an error panel; reinstall `dictionary/wordnet.zdict` and verify its checksum. Notes unresolved after EPUB changes remain exportable; do not force them onto guessed positions. Back up JSON files before any recovery. Logs can contain book paths and excerpts: scrub them before sharing.

## Light or sleep unavailable

Missing/failed LIPC commands are reported as unavailable or restore the last confirmed values. No sysfs workaround is supported. Keep sleep OFF. Transition failures disable experimental sleep; restore the UI rather than repeatedly retrying. The detailed test plan is in TESTING and the historical manual.
