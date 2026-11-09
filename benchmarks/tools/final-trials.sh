#!/bin/sh
set -eu
B=/mnt/us/zreader/.bench
finish_reader() {
 for p in $(pidof zreader reader.lua luajit 2>/dev/null); do kill -TERM "$p" 2>/dev/null || :; done
 sleep 3
 sh /mnt/us/zreader/zreader-maintenance.sh restore-ui >/dev/null 2>&1 || :
}
trap 'finish_reader' EXIT HUP INT TERM
memory() {
 p=$(pidof "$1" | awk '{print $1}')
 [ -n "$p" ] || exit 2
 awk '/^VmRSS:|^VmHWM:/{print}' /proc/$p/status >"$B/$2-memory.txt"
}
trial() {
 label=$1
 "$B/probe" turns "$2" >"$B/$label-warmup.csv"
 "$B/probe" turns 20 >"$B/$label-turns.csv"
 memory "$3" "$label"
 "$B/probe" shot >"$B/$label-pre.pgm"
 "$B/probe" rapid >"$B/$label-rapid.csv"
 "$B/probe" shot >"$B/$label-post.pgm"
 finish_reader
 echo "completed $label"
}
trial ko-epub 8 reader.lua
nohup sh /mnt/us/zreader/zreader-run.sh "$B/book.pdf" >"$B/z-pdf-launch.log" 2>&1 </dev/null &
sleep 12
trial z-pdf 10 zreader
nohup sh /mnt/us/koreader/koreader.sh "$B/book.pdf" >"$B/ko-pdf-launch.log" 2>&1 </dev/null &
sleep 15
trial ko-pdf 10 reader.lua
# Restore the user's history, global reader settings, and Zig Reader reading positions.
cp -p "$B/ko-bak/settings.reader.lua" /mnt/us/koreader/settings.reader.lua
for f in history.lua history.lua.old; do
 if [ -f "$B/ko-bak/$f" ]; then cp -p "$B/ko-bak/$f" "/mnt/us/koreader/$f"; else rm -f "/mnt/us/koreader/$f"; fi
done
rm -rf /mnt/us/zreader/state
cp -rp "$B/z-bak/state" /mnt/us/zreader/state
cp -p "$B/z-bak/last_book" /mnt/us/zreader/last_book
cmp "$B/ko-bak/settings.reader.lua" /mnt/us/koreader/settings.reader.lua && echo settings_restored
for n in awesome volumd blanket Xorg; do
 for p in $(pidof "$n"); do awk -v n="$n" '/^State:/{print n,$0}' /proc/$p/status; done
done
