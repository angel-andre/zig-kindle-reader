# Install or upgrade 0.9.0

These are explicit manual instructions, not an automatic device installer. All writes are to the user storage partition. Start with PREREQUISITES and keep SSH recovery available.

## 1. Verify and inspect on your computer

From the repository root:

```sh
sha256sum -c release/SHA256SUMS
# macOS alternative: shasum -a 256 -c release/SHA256SUMS
tar -tzf release/zr090.tgz
```

Expected runtime members: `out/zreader`, `zreader-run.sh`, `zreader-maintenance.sh`, `dictionary/`, `kual/zreader/`, `README`, `COPYING`. Install the **runtime**, never a source archive or development fixtures.

The executable's expected SHA-256 is:

```text
4d037283147b8d66f3bbe186ee30bb2569e436a5214f4d7500a903fc265e3418
```

## 2. Close readers and back up

Quit KOReader and Zigg Reader to the normal Kindle interface. Disconnect USB mass storage. With the SSH variables from PREREQUISITES set:

```sh
ssh -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -p 2222 root@"$KINDLE_HOST"  'df -k /mnt/us; df -k /tmp; test ! -e /mnt/us/zreader-backup-before-07.tgz'
```

If an old backup exists, copy it to your computer and choose a different backup name; do not overwrite it. On an upgrade:

```sh
ssh -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -p 2222 root@"$KINDLE_HOST"  'cd /mnt/us && tar -czf zreader-backup-before-07.tgz zreader'
```

On a first install there is no existing `zreader` directory to back up. Independently back up `/mnt/us/Books`, and back up an existing `/mnt/us/extensions/zreader` if present. Copy the backup off-device too:

```sh
scp -O -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -P 2222  root@"$KINDLE_HOST":/mnt/us/zreader-backup-before-07.tgz .
```

`-O` selects legacy SCP for older Dropbear servers without SFTP. If your older SCP client does not recognize it, omit `-O`.

## 3. Stage on user storage, not /tmp

```sh
scp -O -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -P 2222  release/zr090.tgz root@"$KINDLE_HOST":/mnt/us/zr090.tgz
ssh -i "$KINDLE_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -p 2222 root@"$KINDLE_HOST"
```

The remaining commands run **on the Kindle**. Use a new empty staging directory; stop if it already exists:

```sh
mkdir /mnt/us/zreader-install-07
cd /mnt/us/zreader-install-07
tar -xzf /mnt/us/zr090.tgz
mkdir -p /mnt/us/zreader/dictionary /mnt/us/extensions
cp out/zreader /mnt/us/zreader/zreader
cp zreader-run.sh zreader-maintenance.sh /mnt/us/zreader/
cp dictionary/wordnet.zdict dictionary/LICENSE dictionary/FORMAT /mnt/us/zreader/dictionary/
cp README COPYING /mnt/us/zreader/
cp -R kual/zreader /mnt/us/extensions/
chmod 755 /mnt/us/zreader/zreader /mnt/us/zreader/zreader-run.sh  /mnt/us/zreader/zreader-maintenance.sh /mnt/us/extensions/zreader/bin/launch.sh
sync
/mnt/us/zreader/zreader --version
```

Expect `0.9.0`. Preserve existing `state/`, `notes/`, `export/`, `settings.json`, `ui07.json` and `last_book`. The runtime does not contain replacement copies of these user files. Make `/mnt/us/Books` if needed and copy your own DRM-free PDFs/EPUBs there.

## 4. First launch

Open KUAL → Zig reader → Zig reader (Library). Continue last book launches the same program at its last book. Debug: timings is optional. Check selection, notes, page turns, library folders and sorting. Keep **Power button sleeps OFF**. Light/warmth controls require available LIPC commands; no light value should change merely on startup. Existing hardware dark mode must remain unchanged.

After successful checks, remove only the upload and staging directory you just created; keep backups until satisfied. Never bulk-clean `/tmp` or delete unrelated user-storage files.

## Recorded install caveat

The Kindle's temporary filesystem is small and can fill up with old install leftovers, so these steps stage files on `/mnt/us` instead. Do not confuse free space on `/mnt/us` with free space on `/tmp` or system partitions.
