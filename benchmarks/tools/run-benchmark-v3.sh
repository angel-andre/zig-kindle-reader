#!/bin/sh
set -eu
B=/mnt/us/zreader/.bench
P="$B/probe-v3"
mkdir -p "$B/results-v3"
R="$B/results-v3"
finish_reader() {
 for p in $(pidof zreader reader.lua luajit 2>/dev/null); do kill -TERM "$p" 2>/dev/null || :; done
 sleep 3
 sh /mnt/us/zreader/zreader-maintenance.sh restore-ui >/dev/null 2>&1 || :
}
restore() {
 finish_reader
 cp -p "$B/ko-bak/settings.reader.lua" /mnt/us/koreader/settings.reader.lua
 for f in history.lua history.lua.old; do
  if [ -f "$B/ko-bak/$f" ]; then cp -p "$B/ko-bak/$f" "/mnt/us/koreader/$f"; else rm -f "/mnt/us/koreader/$f"; fi
 done
 rm -rf /mnt/us/zreader/state
 cp -rp "$B/z-bak/state" /mnt/us/zreader/state
 cp -p "$B/z-bak/last_book" /mnt/us/zreader/last_book
 cmp "$B/ko-bak/settings.reader.lua" /mnt/us/koreader/settings.reader.lua && echo settings_restored
 cmp "$B/z-bak/last_book" /mnt/us/zreader/last_book && echo last_book_restored
 diff -qr "$B/z-bak/state" /mnt/us/zreader/state >/dev/null && echo state_restored
 for n in awesome volumd blanket Xorg; do
  pids=$(pidof "$n"); [ -n "$pids" ] || return 1
  for p in $pids; do awk -v n="$n" '/^State:/{print n,$0}' /proc/$p/status; done
 done
 if pidof zreader reader.lua luajit >/dev/null; then echo ERROR_reader_remaining; return 1; else echo no_reader_remaining; fi
}
trap 'restore >"$R/restore-status.txt" 2>&1' EXIT
memory() {
 max=0; hwm=0; count=0
 for p in $(pidof "$1"); do
  rss=$(awk '/^VmRSS:/{print $2}' /proc/$p/status); hw=$(awk '/^VmHWM:/{print $2}' /proc/$p/status)
  count=$((count+1)); if [ "${rss:-0}" -gt "$max" ]; then max=$rss; hwm=${hw:-0}; fi
 done
 printf 'VmRSS_kB,VmHWM_kB,matching_processes\n%s,%s,%s\n' "$max" "$hwm" "$count" >"$R/$2-memory.csv"
}
trial() {
 label=$1
 "$P" turns 2 >"$R/$label-validation.csv"
 awk -F, 'NR>1 && $4!=1 {bad=1} END {exit bad}' "$R/$label-validation.csv"
 "$P" turns "$2" >"$R/$label-warmup.csv"
 "$P" turns 20 >"$R/$label-turns.csv"
 memory "$3" "$label"
 "$P" shot >"$R/$label-pre.pgm"
 if [ "$3" = zreader ]; then grep 'page refresh:' /mnt/us/zreader.log | tail -1 >"$R/$label-pre-page.txt"; fi
 "$P" rapid >"$R/$label-rapid.csv"
 "$P" shot >"$R/$label-post.pgm"
 if [ "$3" = zreader ]; then grep 'page refresh:' /mnt/us/zreader.log | tail -1 >"$R/$label-post-page.txt"; fi
 finish_reader
 echo "completed $label"
}
# Restart each reader after stock UI restore; three-pixel alternating taps defeat kernel ABS deduplication.
nohup sh /mnt/us/koreader/koreader.sh "$B/book.epub" >"$B/ko-epub-v3.log" 2>&1 </dev/null &
sleep 12
trial ko-epub 8 reader.lua
# Fresh isolated EPUB state for the Zig Reader rerun, keeping original backups intact.
rm -rf /mnt/us/zreader/state
mkdir -p /mnt/us/zreader/state
nohup sh /mnt/us/zreader/zreader-run.sh "$B/book.epub" >"$B/z-epub-rerun.log" 2>&1 </dev/null &
sleep 12
trial z-epub 8 zreader
nohup sh /mnt/us/zreader/zreader-run.sh "$B/book.pdf" >"$B/z-pdf-launch.log" 2>&1 </dev/null &
sleep 12
trial z-pdf 8 zreader
nohup sh /mnt/us/koreader/koreader.sh "$B/book.pdf" >"$B/ko-pdf-launch.log" 2>&1 </dev/null &
sleep 25
trial ko-pdf 8 reader.lua
# Repeated direct-to-book launch trials: warm OS/document caches, restarted app.
for app in z ko; do
 for book in epub pdf; do
  for i in 1 2 3; do
   if [ "$app" = z ]; then
    cmd="sh /mnt/us/zreader/zreader-run.sh '$B/book.$book' >'$B/launch-temp.log' 2>&1"
    log=/mnt/us/zreader.log; token='page refresh:'
   else
    cmd="sh /mnt/us/koreader/koreader.sh '$B/book.$book' >'$B/launch-temp.log' 2>&1"
    log=/mnt/us/koreader/crash.log; token='Restoring user input handling'
   fi
   "$P" launch "$cmd" "$log" "$token" >"$R/$app-$book-open-$i.csv"
   "$P" shot >"$R/$app-$book-open-$i.pgm"
   finish_reader
   echo "open $app $book $i"
  done
 done
 # Library/file-browser launch uses only a stability proxy; screenshots must verify it.
 for i in 1 2 3; do
  if [ "$app" = z ]; then
   cmd="sh /mnt/us/zreader/zreader-run.sh @library >'$B/launch-temp.log' 2>&1"; log=/mnt/us/zreader.log
  else
   cmd="sh /mnt/us/koreader/koreader.sh '$B' >'$B/launch-temp.log' 2>&1"; log=/mnt/us/koreader/crash.log
  fi
  "$P" launch "$cmd" "$log" - >"$R/$app-library-$i.csv"
  "$P" shot >"$R/$app-library-$i.pgm"
  finish_reader
  echo "library $app $i"
 done
done
/mnt/us/zreader/zreader --version >"$R/z-version.txt" 2>&1 || :
cp /mnt/us/koreader/git-rev "$R/ko-version.txt"
restore >"$R/restore-status.txt" 2>&1
trap - EXIT
cat "$R/restore-status.txt"
tar -czf "$B/results-v3.tar.gz" -C "$B" results-v3
