#!/bin/sh
# Opt-in, reversible USB-partition marker; never edits rootfs/upstart/core_pattern.
set -eu
US=${ZREADER_US:-/mnt/us}
DATA=${ZREADER_DATA:-$US/zreader}
case "$US" in /*) ;; *) echo 'USB root must be absolute' >&2; exit 1;; esac
[ "$US" != / ] && [ -d "$US" ] || { echo 'USB root unavailable/refusing /' >&2; exit 1; }
MARKER=$US/DISABLE_CORE_DUMP
STATE=$DATA/maintenance
OWNED=$STATE/core-marker-owned
fail() { echo "$*" >&2; exit 1; }
identity() { stat -c '%d:%i' "$1"; }
case "${1:-status}" in
 restore-ui)
    # Emergency recovery is independent of reader state/settings. It never writes
    # sysfs or changes grayscale/dark mode; no framework/jailbreak job is stopped.
    bounded() {
        "$@" & cmd=$!
        ( sleep 3; kill -KILL "$cmd" 2>/dev/null || : ) & guard=$!
        rc=0; wait "$cmd" || rc=$?
        kill "$guard" 2>/dev/null || :
        wait "$guard" 2>/dev/null || :
        return "$rc"
    }
    bounded killall -TERM zreader 2>/dev/null || :
    sleep 1
    bounded killall -KILL zreader 2>/dev/null || :
    for p in awesome volumd blanket Xorg; do bounded killall -CONT "$p" 2>/dev/null || :; done
    bounded lipc-set-prop -i com.lab126.powerd preventScreenSaver 0 || :
    bounded restart pillow || bounded start pillow || :
    bounded lipc-set-prop com.lab126.pillow disableEnablePillow enable || :
    bounded restart statusbar || bounded start statusbar || :
    bounded lipc-set-prop com.lab126.appmgrd start app://com.lab126.booklet.home || :
    echo 'Recovery commands completed: reader stop, UI resume, pillow/statusbar restart, powerd inhibitor clear requested. Verify the screen.'
    echo 'If still asleep, press power once. Light and dark-mode settings were not changed.'
    ;;
 status)
    if [ -L "$MARKER" ]; then echo 'Marker is a symlink: refusing to follow it'; exit 1; fi
    if [ -e "$MARKER" ]; then echo "Core-dump suppression marker present: $MARKER"; else echo 'Core-dump suppression marker absent'; fi
    [ ! -f "$OWNED" ] || echo "Ownership receipt present: $OWNED"
    echo 'Marker support is firmware-dependent; no firmware or kernel settings were changed.'
    ;;
 disable-core-dumps|undo-core-dumps)
    [ ! -L "$STATE" ] || fail 'Maintenance state is a symlink'
    mkdir -p "$STATE"
    LOCK=$STATE/core-marker-lock
    mkdir "$LOCK" 2>/dev/null || fail 'Another maintenance operation is running (or stale lock exists)'
    trap 'rmdir "$LOCK" 2>/dev/null || :' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    [ ! -L "$MARKER" ] || fail 'Marker is a symlink; nothing changed'
    [ ! -L "$OWNED" ] || fail 'Ownership receipt is a symlink; nothing changed'
    if [ "$1" = disable-core-dumps ]; then
        if [ -e "$MARKER" ]; then
            echo 'Marker already exists; preserved unchanged. Undo only removes a marker this helper created.'
            exit 0
        fi
        command -v stat >/dev/null 2>&1 || fail 'stat required for safe ownership tracking'
        identity "$STATE" >/dev/null || fail 'stat -c unavailable; nothing changed'
        ( set -C; : > "$MARKER" ) || fail 'Marker creation failed; nothing overwritten'
        ID=$(identity "$MARKER")
        ( set -C; printf '%s\n' "$ID" > "$OWNED.tmp.$$" ) || fail 'Marker created, receipt failed: inspect manually; no automatic undo'
        mv "$OWNED.tmp.$$" "$OWNED"
        echo "Created $MARKER. No existing dumps were deleted; no system setting was edited."
    else
        [ -f "$OWNED" ] || { echo 'No owned marker: nothing removed (pre-existing markers are preserved).'; exit 0; }
        if [ ! -e "$MARKER" ]; then rm "$OWNED"; echo 'Marker already absent; receipt removed'; exit 0; fi
        [ -f "$MARKER" ] && [ ! -s "$MARKER" ] || fail 'Marker is no longer an empty regular file; preserved'
        IFS= read -r ID < "$OWNED"
        [ "$ID" = "$(identity "$MARKER")" ] || fail 'Marker was replaced by someone else; preserved'
        rm "$MARKER"
        rm "$OWNED"
        echo 'Removed only the empty marker created by this helper. Crash-dump saving may resume.'
    fi
    ;;
 clear-cache)
    # Deletes only the reader's saved page images (instant reopen); books, notes,
    # reading positions and settings are not touched. Safe while the reader is closed.
    PAGES=$DATA/cache/pages
    [ ! -L "$DATA/cache" ] && [ ! -L "$PAGES" ] || fail 'Cache path is a symlink; nothing removed'
    if [ -d "$PAGES" ]; then
        n=0
        for f in "$PAGES"/*.pg "$PAGES"/*.pg.tmp; do [ -f "$f" ] || continue; rm -f "$f"; n=$((n+1)); done
        echo "Removed $n saved page image(s) from $PAGES"
    else
        echo 'No saved page images'
    fi
    ;;
 *) echo "Usage: $0 [status|disable-core-dumps|undo-core-dumps|restore-ui|clear-cache]" >&2; exit 2;;
esac
