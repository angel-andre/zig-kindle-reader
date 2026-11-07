# Prerequisites and access

## Supported starting point

- Kindle Paperwhite 12th generation, already jailbroken by a method appropriate for its firmware.
- Working KUAL and working KOReader installation. The included launcher can use KOReader's bundled Dropbear at `/mnt/us/koreader/dropbear`; KOReader itself is not the rendering engine.
- SSH already configured for authorized public-key login on port 2222. Password authentication must be disabled. The “no-password login” option must remain unticked: no-auth access is not the same as key-only access.
- A computer with `ssh`, `scp`, `tar` and a SHA-256 utility; a trusted reachable local network and the Kindle's current address.
- A backup and enough user-partition free space. See INSTALL.

The recorded device had KUAL, KOReader and key-only SSH working before the reader was installed. The available record does **not** establish the jailbreak exploit, firmware version, KUAL installer sequence, first-time public-key provisioning procedure, hotspot setup sequence or a tested USBNetwork setup. This repository deliberately does not invent those steps. Follow the current upstream documentation appropriate to your already-jailbroken device. Do not upgrade firmware merely to match this project.

For reference: [KOReader](https://github.com/koreader/koreader), [KOReader Kindle setup](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices). USBNetwork is a possible access route, not a route validated here.

## Connection template

Replace placeholders locally. Do not put an actual address, network name or personal path into an issue or commit.

```sh
export KINDLE_HOST='<kindle-ip>'
export KINDLE_KEY='<path-to-your-private-key>'
ssh -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes   -o ConnectTimeout=10 -p 2222 root@"$KINDLE_HOST" 'printf "SSH ready\n"; df -k /mnt/us'
```

The private key stays on the computer. Only its public counterpart belongs in the device's authorized-key configuration. The included launcher starts Dropbear with `-s` if needed, using KOReader's established setup. It does not provision authorized keys for you. Test SSH **before** launching the reader and do not expose port 2222 to the internet.
