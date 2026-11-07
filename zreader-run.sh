#!/bin/sh
# Standalone launcher: Amazon UI paused the way koreader.sh does it, SSH kept reachable.
# Usage: zreader-run.sh [zreader options] [book | @library | @last | @epub]
ulimit -c 0 2>/dev/null || :
# v0.9.4 launch profile: uptime readings for the reader's "launch profile" log line.
ZR_LAUNCH_T0=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
export ZR_LAUNCH_T0
DIR=/mnt/us/zreader
LOG=/mnt/us/zreader.log
ERR=/mnt/us/zreader-stderr.log
KO=/mnt/us/koreader
PORT=2222
GOV=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
FB=/tmp/zreader-fb.raw
PAUSED=""
STOPPED_SB=""
OLD_GOV=""

log() { echo "$(date '+%F %T') zreader-run: $*" >>"$LOG"; }
lipc() { lipc-set-prop "$@" >/dev/null 2>&1; }

# Optional reversible firmware marker, NEVER applied unless explicitly enabled.
# Only touches /mnt/us; undo with zreader-maintenance.sh undo-core-dumps.
if [ "${ZREADER_DISABLE_CORE_DUMPS:-0}" = 1 ]; then
    "$DIR/zreader-maintenance.sh" disable-core-dumps >>"$LOG" 2>>"$ERR" || log "core-dump marker could not be applied"
fi

restore() {
	trap - EXIT INT TERM HUP
	[ -n "$OLD_GOV" ] && echo "$OLD_GOV" >"$GOV" 2>/dev/null
	if [ -n "$PAUSED" ]; then
		for p in $PAUSED; do killall -CONT "$p" >/dev/null 2>&1; done
		[ -s "$FB" ] && cat "$FB" >/dev/fb0 2>/dev/null
		[ -n "$STOPPED_SB" ] && start statusbar >/dev/null 2>&1
		lipc com.lab126.pillow disableEnablePillow enable
		lipc com.lab126.appmgrd start app://com.lab126.booklet.home
		lipc com.lab126.powerd preventScreenSaver 0
		log "Amazon UI resumed"
	fi
	rm -f "$FB"
	log "done (dropbear left running if started)"
}
trap restore EXIT
trap 'exit 130' INT TERM HUP

# Last argument is the book (or an @ shortcut); everything before it is passed through.
BOOK=""
OPTS=""
for a in "$@"; do
	[ -n "$BOOK" ] && OPTS="$OPTS $BOOK"
	BOOK="$a"
done
case "$BOOK" in
	--*) OPTS="$OPTS $BOOK"; BOOK="" ;;
	@library|"") BOOK="" ;;
	@epub) BOOK=$(find /mnt/us/Books -iname '*.epub' 2>/dev/null | head -n 1) ;;
	@last) BOOK=$(cat "$DIR/last_book" 2>/dev/null) ;;
esac
if [ -n "$BOOK" ] && [ ! -f "$BOOK" ]; then
	log "book not found: '$BOOK', opening Library"
	BOOK=""
fi

if ps w 2>/dev/null | grep -q '[r]eader.lua'; then
	log "KOReader is running (it holds the touch grab); quit KOReader first"
	exit 1
fi

# SSH: KOReader's dropbear, as its SSH plugin starts it, key-only (-s).
# v0.9.4: runs in the background, overlapping the UI pause (dropbear daemonizes
# itself; the reader never waits for it).
start_ssh() {
if ! netstat -ltn 2>/dev/null | grep -q ":$PORT "; then
	if [ -x "$KO/dropbear" ]; then
		iptables -C INPUT -p tcp --dport $PORT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT 2>/dev/null ||
			iptables -A INPUT -p tcp --dport $PORT -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
		iptables -C OUTPUT -p tcp --sport $PORT -m conntrack --ctstate ESTABLISHED -j ACCEPT 2>/dev/null ||
			iptables -A OUTPUT -p tcp --sport $PORT -m conntrack --ctstate ESTABLISHED -j ACCEPT
		mkdir -p "$KO/settings/SSH"
		(cd "$KO" && ./dropbear -E -R -p $PORT -P /tmp/dropbear_koreader.pid -s) >>"$LOG" 2>&1 &&
			log "dropbear started on $PORT (key-only)" || log "dropbear failed to start"
	fi
fi
}
start_ssh </dev/null &


# Pause the Amazon UI (koreader.sh style): keep X alive but stopped, pillow off.
# v0.9.4: the screen snapshot runs alongside the LIPC calls, and the 0.3 s
# settle delay after disabling pillow now overlaps the statusbar stop instead
# of following it. Same steps, same order of effects before X is stopped.
cat /dev/fb0 >"$FB" 2>/dev/null &
FB_PID=$!
lipc com.lab126.powerd preventScreenSaver 1
lipc com.lab126.pillow disableEnablePillow disable
( usleep 300000 2>/dev/null || sleep 1 ) &
SETTLE_PID=$!
if status statusbar 2>/dev/null | grep -q "start/running"; then
	stop statusbar >/dev/null 2>&1 && STOPPED_SB=1
fi
wait "$SETTLE_PID" 2>/dev/null
wait "$FB_PID" 2>/dev/null
for p in awesome volumd blanket Xorg; do
	killall -STOP "$p" >/dev/null 2>&1 && PAUSED="$PAUSED $p"
done
log "paused:$PAUSED"

OLD_GOV=$(cat "$GOV" 2>/dev/null)

log "running zreader$OPTS '$BOOK'"
ZR_LAUNCH_EXEC=$(cut -d' ' -f1 /proc/uptime 2>/dev/null)
export ZR_LAUNCH_EXEC
# shellcheck disable=SC2086
if [ -n "$BOOK" ]; then
	"$DIR/zreader" --data "$DIR" --books /mnt/us/Books --log "$LOG" $OPTS "$BOOK" >/dev/null 2>>"$ERR"
else
	"$DIR/zreader" --data "$DIR" --books /mnt/us/Books --log "$LOG" $OPTS >/dev/null 2>>"$ERR"
fi
log "zreader exited rc=$?"
