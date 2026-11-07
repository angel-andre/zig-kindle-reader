# Provenance and verification boundaries

Documentation assembled November 6, 2026 (Toronto). Sources are the existing reader source tree, runtime package, host test reports and the carried-over device-work record. The available transcript search returned no historical messages in this delegated session; missing setup details are explicitly left unverified.

## Recorded on-device outcomes

The working account records a jailbroken PW6 with KUAL/KOReader and key-only SSH on port 2222; removal of old crash diagnostics and VoiceView voice data; user storage around 9.2 GB free; temporary-install-space cleanup; backups before the later installation; installation and version check of 0.7.0. These statements are carried-over recorded outcomes, not a fresh hardware audit.

## Directly checked during repository assembly

- All 24 Zig unit-suite checks passed from the copied tree using existing local fixture inputs read-only; script syntax and checksum verification also passed.
- Existing source/build scripts and package layout were inspected without changing application code.
- MuPDF 1.28.6 source archive SHA-256 was computed; every archived file matched the existing extracted tree, with no missing files.
- The official exact-version download route was reachable.
- Runtime/dictionary hashes were recomputed and original-size records retained.
- Selected screenshots were visually inspected: synthetic books only, with metadata removed.
- Text/files/archive payloads were screened for personal identifiers, credentials and network details; see PRIVACY_REVIEW.

## Not established

The exact jailbreak exploit/firmware, first-time KUAL/SSH/hotspot/USBNetwork procedure, final marker-creation output and global crash-suppression effectiveness are not established by accessible evidence. Physical panel ghosting, new light controls, experimental sleep, battery, passcodes and comparative KOReader speed have not been newly verified. No device or personal-computer command was run during this assembly.

Historical reports and the original runtime README retain their original “not deployed” labels. They are not rewritten as hardware evidence merely because a subsequent installation was reported.
