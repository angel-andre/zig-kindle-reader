#!/bin/sh
# zreader on-device benchmark (bench105, for 0.10.4). Run over SSH while zreader is NOT running.
# Headless: never opens /dev/fb0 or the touch screen, never changes the light, Wi-Fi or
# Amazon UI, and never reads or writes /mnt/us/zreader state, notes,
# settings or caches: everything goes to a temporary folder that is deleted at the end.
#   sh /mnt/us/zreader/bench/zrbench.sh [-l LIBRARY_DIR] BOOK...
# BOOK is a path, or a name searched (case-insensitive) in /mnt/us/documents and /mnt/us/Books.
# The report is printed and saved as /mnt/us/zreader/bench/report-DATE.txt.
# bench105: for the whole run the CPU governor is set to "performance", as the reader does
# while it renders (zreader --sim never touches it), and powerd is kept from sleeping
# (preventScreenSaver 1). Both are restored on exit, Ctrl-C or kill (governor to its
# previous value, preventScreenSaver to 0). ZRBENCH_GOVERNOR=keep leaves the governor alone.
set -u
B=$(cd "$(dirname "$0")" && pwd)
ZR=${ZREADER:-/mnt/us/zreader/zreader}
LIB=""
[ "${1:-}" = "-l" ] && { LIB=$2; shift 2; }
[ -z "$LIB" ] && { [ -d /mnt/us/Books ] && LIB=/mnt/us/Books || LIB=/mnt/us/documents; }
[ $# -gt 0 ] || { echo "usage: $0 [-l LIBRARY_DIR] BOOK..."; exit 2; }
if pidof zreader >/dev/null 2>&1; then echo "zreader is running; quit it first"; exit 1; fi
[ -x "$ZR" ] || { echo "reader binary not found: $ZR"; exit 1; }
T=$B/tmp.$$
mkdir -p "$T" || exit 1
GOV=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
OLD_GOV=""
WAKE=""
cleanup() {
	trap - EXIT INT TERM HUP
	[ -n "$OLD_GOV" ] && echo "$OLD_GOV" >"$GOV" 2>/dev/null
	[ -n "$WAKE" ] && lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1
	rm -rf "$T"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
if lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1; then WAKE=1; fi
GOV_NOTE="left as is"
if [ "${ZRBENCH_GOVERNOR:-performance}" != keep ] && [ -w "$GOV" ] && grep -qw performance /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
	cur=$(cat "$GOV" 2>/dev/null)
	if [ "$cur" != performance ]; then
		OLD_GOV=$cur
		echo performance >"$GOV" 2>/dev/null || OLD_GOV=""
	fi
	[ "$(cat "$GOV" 2>/dev/null)" = performance ] && GOV_NOTE="set to performance like the reader while rendering (was ${cur:-?}; restored at exit)"
fi
REPORT=$B/report-$(date +%Y%m%d-%H%M%S).txt
out() { echo "$*" | tee -a "$REPORT"; }
# Timestamp each stderr line with /proc/uptime (10 ms resolution), without forking per line.
stamp() { while IFS= read -r l; do read up _ </proc/uptime; echo "$up $l"; done; }
# Run the reader headless (--sim) in the background; sample its peak RSS (VmHWM) until it exits.
run_sim() { # data script logfile book...
	d=$1 s=$2 lf=$3; shift 3
	"$ZR" --sim "$s" --shots "$T/shots" --data "$d" --books "$LIB" --idle-min 0 "$@" 2>"$lf.raw" >/dev/null &
	pid=$!; hwm=0
	while kill -0 $pid 2>/dev/null; do
		v=$(sed -n 's/^VmHWM:[[:space:]]*\([0-9]*\).*/\1/p' /proc/$pid/status 2>/dev/null)
		[ -n "$v" ] && [ "$v" -gt "$hwm" ] && hwm=$v
		usleep 200000 2>/dev/null || sleep 1
	done
	wait $pid; echo "rc=$? rss_peak_kb=$hwm" >>"$lf.raw"
}
find_book() {
	case "$1" in /*) [ -f "$1" ] && echo "$1"; return;; esac
	find ${BOOKDIRS:-/mnt/us/documents /mnt/us/Books} -type f -iname "*$1*" 2>/dev/null | grep -iE '\.(pdf|epub|mobi|azw3|txt|cbz|fb2)$' | head -n 1
}
sim_summary() { # label logfile
	f=$2.raw
	ff=$(sed -n 's/.*open profile: first_frame_us=\([0-9]*\).*/\1/p' "$f" | head -n 1)
	dr=$(grep -c 'first page drawn as a draft' "$f")
	ex=$(sed -n 's/.*draft replaced by the exact page.* after \([0-9]*\)us.*/\1/p' "$f" | head -n 1)
	sp=$(sed -n "s/^slow pages: [A-Za-z]* \(avg=[0-9]*ms max=[0-9]*ms\).*/\1/p" "$f" | head -n 1)
	tc=$(sed -n 's/^touch-up -> complete *\(n=.*\)/\1/p' "$f" | tr -s ' ')
	rw=$(sed -n 's/^render (workers) *\(n=.*\)/\1/p' "$f" | tr -s ' ')
	rs=$(sed -n 's/^rc=\([0-9]*\) rss_peak_kb=\([0-9]*\)/rc=\1 rss_peak_kb=\2/p' "$f")
	out "  $1: first_frame_ms=$(( ${ff:-0} / 1000 )) draft=$dr exact_page_ms=$(( ${ex:-0} / 1000 )) first8_$sp"
	out "    turn(touch-up->complete,us): $tc"
	out "    render(workers,us): $rw"
	out "    reader $rs"
}
out "== zreader bench $(date '+%F %T') =="
out "reader: $("$ZR" --version 2>&1 | head -n 1)  bench: $(sha256sum "$B/zrbench" 2>/dev/null | cut -c1-12)"
out "kernel: $(uname -r)  cpus: $(grep -c ^processor /proc/cpuinfo)  governor: $(cat $GOV 2>/dev/null) ($GOV_NOTE) cur_khz: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null) max_khz: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)"
out "powerd wake lock: $([ -n "$WAKE" ] && echo "held (preventScreenSaver 1, set back to 0 at exit)" || echo "not available")"
out "mem: $(grep -E '^(MemTotal|MemAvailable):' /proc/meminfo | tr -s ' ' | tr '\n' ' ')  load: $(cut -d' ' -f1-3 /proc/loadavg)"
for name in "$@"; do
	BK=$(find_book "$name")
	if [ -z "$BK" ]; then out "-- $name: not found"; continue; fi
	out ""
	out "-- book: $(basename "$BK") ($(wc -c <"$BK") bytes)"
	sync; echo "   (zrbench: open, renders, prerender model)" >/dev/null
	"$B/zrbench" book "$BK" "$T/zb" 30 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
	rm -rf "$T/zb"
	# Real reader, headless: cold open (empty data folder) + 30 turns at 0.7 s,
	# then warm reopen (page and layout caches present) + 30 fast turns at 0.25 s.
	{ echo "wait 4000"; i=0; while [ $i -lt 30 ]; do echo "tap 1180 850"; echo "wait 700"; i=$((i+1)); done; echo "wait 1500"; echo quit; } >"$T/turn700.sim"
	{ echo "wait 4000"; i=0; while [ $i -lt 30 ]; do echo "tap 1180 850"; echo "wait 250"; i=$((i+1)); done; echo "wait 1500"; echo quit; } >"$T/turn250.sim"
	rm -rf "$T/d"; mkdir -p "$T/d"
	run_sim "$T/d" "$T/turn700.sim" "$T/cold" "$BK"; sim_summary "reader cold, 30 turns @0.7s" "$T/cold"
	run_sim "$T/d" "$T/turn250.sim" "$T/warm" "$BK"; sim_summary "reader warm, 30 turns @0.25s" "$T/warm"
done
# bench105: MuPDF built -O2 (zrbench-o2) vs the shipped -Os build (zrbench): rendered
# pixels must be identical; render times are compared on the same pages.
if [ -x "$B/zrbench-o2" ]; then
	out ""
	out "-- MuPDF -O2 vs -Os (same render code, same pages)"
	for name in "$@"; do
		BK=$(find_book "$name"); [ -n "$BK" ] || continue
		a=$("$B/zrbench" hash "$BK" 40 2>/dev/null); b=$("$B/zrbench-o2" hash "$BK" 40 2>/dev/null)
		ha=$(echo "$a" | sed -n 's/.*hash=\([0-9a-f]*\).*/\1/p'); hb=$(echo "$b" | sed -n 's/.*hash=\([0-9a-f]*\).*/\1/p')
		ta=$(echo "$a" | sed -n 's/.*render_mean_ms=\([0-9.]*\).*/\1/p'); tb=$(echo "$b" | sed -n 's/.*render_mean_ms=\([0-9.]*\).*/\1/p')
		same=DIFFERENT; [ -n "$ha" ] && [ "$ha" = "$hb" ] && same=identical
		out "  $(basename "$BK"): pixels $same (Os $ha, O2 $hb); render mean Os ${ta}ms O2 ${tb}ms"
	done
fi
out ""
out "-- library: $LIB"
printf 'wait 20000\nquit\n' >"$T/lib.sim"
rm -rf "$T/d"; mkdir -p "$T/d"
for pass in cold cached; do
	read t0 _ </proc/uptime
	"$ZR" --sim "$T/lib.sim" --shots "$T/shots" --data "$T/d" --books "$LIB" --idle-min 0 2>&1 >/dev/null | stamp >"$T/lib-$pass"
	n=$(sed -n 's/.*library: \([0-9]*\) books.*/\1/p' "$T/lib-$pass" | head -n 1)
	scan=$(sed -n 's/.*setup..library=\([0-9-]*\)ms.*/\1/p' "$T/lib-$pass" | head -n 1)
	ff=$(sed -n 's/.*library..first_frame=\([0-9-]*\)ms.*/\1/p' "$T/lib-$pass" | head -n 1)
	pend=$(sed -n 's/.*covers pending=\([0-9]*\).*/\1/p' "$T/lib-$pass" | head -n 1)
	last=$(grep 'library covers:' "$T/lib-$pass" | tail -n 1 | cut -d' ' -f1)
	start=$(head -n 1 "$T/lib-$pass" | cut -d' ' -f1)
	cov="none pending"
	[ -n "$last" ] && cov=$(awk -v a="$start" -v b="$last" 'BEGIN{printf "%d", (b-a)*1000}')
	out "  $pass: books=$n scan_ms=$scan first_frame_after_scan_ms=$ff covers_pending_at_first_frame=${pend:-0} last_cover_batch_ms_after_start=$cov ($(grep -c 'library covers:' "$T/lib-$pass") batches)"
done
out ""
out "-- dictionary"
D=$(dirname "$ZR")/dictionary; "$B/zrbench" dict "$D/wordnet.zdict" "$D/latin.zdict" 2>/dev/null | sed 's/^/  /' | tee -a "$REPORT"
out ""
out "report: $REPORT"
