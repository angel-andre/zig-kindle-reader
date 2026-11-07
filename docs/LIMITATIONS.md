# Known limitations

- Only Paperwhite 12th generation / PW6 at 1272×1696, 8 bpp has been used. Other devices, drivers, resolutions and firmware versions are not validated.
- The installed version was checked, but new light curves, suspend/wake, battery drain, raw power grab, Hall sensor, passcode behavior and long hibernation still need physical validation. Experimental sleep is OFF by default.
- The recorded jailbreaking and initial network/key provisioning sequence is incomplete. This is not a jailbreak tutorial or firmware compatibility guarantee.
- No OCR, DRM removal, pinch-to-zoom or cross-page phrase-search guarantee. PDF pan applies on release.
- Offline dictionary and keyboard are English-oriented. Simple normalization is not a full morphology engine.
- EPUB anchor indexes are bounded; complex order/checksum failures stay unresolved rather than drawing a guessed highlight. Same-basename books retain legacy annotation/export collisions.
- Large or complex covers deliberately time out or hit memory bounds and show placeholders. A synthetic sparse 175 MiB PDF is not equivalent to a 175 MiB scanned book.
- Thumbnail refresh uses next-session path/size/mtime identity, not a live file watcher.
- Hardware dark mode is preserved but not simulated in screenshots. GC16 policy checks do not prove absence of physical ghosting.
- Malformed calibre PDF drop-cap overlap also occurs in independent MuPDF/Poppler renders. No layout repair was fabricated.
- Firmware honoring DISABLE_CORE_DUMP is not guaranteed. Removing old dumps does not prevent new crashes; exact marker application status remains unverified in accessible evidence.
- Benchmark comparison with KOReader is pending. No throughput, latency, battery or “faster than KOReader” claim is supported.
- Historical private-book tests need external inputs/reference images not distributed here. Full fresh-install and documentation replay remain outstanding.
