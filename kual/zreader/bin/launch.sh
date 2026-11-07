#!/bin/sh
# Detach from KUAL, since the launcher stops the UI that started us.
if command -v setsid >/dev/null 2>&1; then
	setsid /bin/sh /mnt/us/zreader/zreader-run.sh "$@" </dev/null >/dev/null 2>&1 &
else
	nohup /bin/sh /mnt/us/zreader/zreader-run.sh "$@" </dev/null >/dev/null 2>&1 &
fi
exit 0
