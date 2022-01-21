#!/bin/sh

backup_apks() {
  mkdir -p apks &&
    (# shellcheck disable=2016
      cd apks &&
        adb wait-for-device shell '
pm list packages -f -3 |
  sed '\''s/package://g;s/\/base.apk=\(.*\)$/ \1/g'\'' |
  xargs -n2 sh -c '\''find "$1"/*.apk -exec echo "{}" "$2" \;'\'' _' |
        xargs -n2 sh -c 'mkdir -p "$2" && adb pull "$1" "$2" &' _
    )
}

exec_adb_shell() {
  adb wait-for-device shell "su -c '$1'"
}

exec_adb_shell_fw() {
  adb wait-for-device forward tcp:5555 tcp:5555
  exec_adb_shell "$1"
}

cleanup_postbackup() {
  DEBUG=${1:-false}
  cat /tmp/send_backup$$*.pid | xargs kill -9 2>/dev/null
  "$DEBUG" && cat /tmp/send_backup$$_*.stdout
  cat /tmp/send_backup$$_*.stderr >&2
  rm /tmp/send_backup$$_*.*
  exit 0
}

backup() {
  (
    trap exit INT HUP TERM
    trap 'cleanup_postbackup "$3"' EXIT
    send_backup_fifo "$1" "$2" >/tmp/send_backup$$_fifo.stdout 2>/tmp/send_backup$$_fifo.stderr &
    echo $! >/tmp/send_backup$$_fifo.pid
    sleep 1
    send_backup_nc >/tmp/send_backup$$_nc.stdout 2>/tmp/send_backup$$_nc.stderr &
    sleep 1
    echo $! >/tmp/send_backup$$_nc.pid
    receive_backup "$1" "$2"
  )
}

send_backup_fifo() {
  if [ "$2" = 'RAW' ]; then
    CMD="busybox dd if=/dev/block/$1 bs=4k of=/cache/fifo"
  else
    CMD="busybox tar -cvf /cache/fifo '$1'"
  fi
  exec_adb_shell_fw "
killall nc 2>/dev/null
busybox rm /cache/fifo 2>/dev/null
busybox mkfifo /cache/fifo
$CMD
"
}

send_backup_nc() {
  exec_adb_shell_fw "
busybox nc -l -p 5555 -e busybox cat /cache/fifo
busybox rm /cache/fifo 2>/dev/null
"
}

receive_backup() {
  if [ "$2" = 'RAW' ]; then
    SIZE=$(adb shell 'su -c "awk '\''/'"$1"'/{print \$3 * 1024}'\'' < /proc/partitions"')
    FNAME="$1".img.gz
  else
    SIZE=$(echo "$(adb shell su -c 'du -s '"$1"'' | cut -f1) * 1024" | bc)
    FNAME="$(printf '%s\n' "$1" | sed 's|^/||g;s|/|%|g')".tar.gz
  fi
  nc -d localhost 5555 |
    pv -s "$SIZE" | gzip -c >"$FNAME"
}
