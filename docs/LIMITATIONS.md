# Known limitations

- Only Paperwhite 12th generation / PW6 at 1272×1696, 8 bpp has been used. Other devices, drivers, resolutions and firmware versions are not validated.
- Light controls, power-button sleep/wake, battery drain, cover sensor, passcode and long hibernation behaviour still need more testing on the device. Sleep is experimental and off by default.
- This is not a jailbreak tutorial; see PREREQUISITES for what you need first.
- No OCR, DRM removal, pinch-to-zoom or cross-page phrase-search guarantee. PDF pan applies on release.
- Offline dictionary and keyboard are English-oriented. Simple normalization is not a full morphology engine.
- EPUB anchor indexes are bounded; complex order/checksum failures stay unresolved rather than drawing a guessed highlight. Same-basename books retain legacy annotation/export collisions.
- Large or complex covers deliberately time out or hit memory bounds and show placeholders. A synthetic sparse 175 MiB PDF is not equivalent to a 175 MiB scanned book.
- Thumbnail refresh uses next-session path/size/mtime identity, not a live file watcher.
- Hardware dark mode is preserved but not simulated in screenshots. GC16 policy checks do not prove absence of physical ghosting.
- Malformed calibre PDF drop-cap overlap also occurs in independent MuPDF/Poppler renders. No layout repair was fabricated.
- Whether firmware honours DISABLE_CORE_DUMP may vary. Removing old dumps does not prevent new crashes.
- The KOReader benchmark covers one device and two books, and measures framebuffer change, not physical e-ink completion.
- Some regression tests need your own book copies in `testbooks/`.
