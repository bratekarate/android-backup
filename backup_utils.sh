#!/bin/sh

backup_apks() {
  mkdir -p apks &&
    (# shellcheck disable=2016
      cd apks &&
        adb wait-for-device shell "pm list packages -f -3" |
        sed 's/package://g;s/base.apk=\(.*\)$/base.apk \1.apk/g' | xargs -n2 sh -c 'adb pull "$1" &' _
    )
}

exec_standalone() {
  adb wait-for-device shell 'su -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh -c \"'"$1"'\""'
}

# setup port forwarding for netcat
forward_adb() {
  adb wait-for-device forward tcp:5555 tcp:5555
}

cleanup_postbackup() {
  cat /tmp/send_backup*.pid | xargs kill -9 2>/dev/null
  cat /tmp/send_backup_*.stderr >&2
  rm /tmp/send_backup_*.*
}

backup() {
  (
    trap exit INT HUP TERM
    trap 'cleanup_postbackup' EXIT
    send_backup_fifo "$1" "$2" >/tmp/send_backup_fifo.stdout 2>/tmp/send_backup_fifo.stderr &
    echo $! >/tmp/send_backup_fifo.pid
    sleep 1
    send_backup_nc >/tmp/send_backup_nc.stdout 2>/tmp/send_backup_nc.stderr &
    sleep 1
    echo $! >/tmp/send_backup_nc.pid
    receive_backup "$1" "$2"
  )
}

send_backup_fifo() {
  if [ "$2" = 'RAW' ]; then
    CMD="dd if=/dev/block/$1 bs=4k of=/cache/fifo"
  else
    CMD="tar -cvf /cache/fifo '$1'"
  fi
  forward_adb
  exec_standalone "
killall nc 2>/dev/null
rm /cache/fifo 2>/dev/null
mkfifo /cache/fifo
$CMD
"
}

send_backup_nc() {
  forward_adb
  exec_standalone "
nc -l -p 5555 -e cat /cache/fifo
rm /cache/fifo 2>/dev/null
"
}

receive_backup() {
  if [ "$2" = 'RAW' ]; then
    SIZE=$(adb shell 'su -c "awk '\''/'"$1"'/{print \$3 * 1024}'\'' < /proc/partitions"')
    FNAME="$1".img.gz
  else
    SIZE=$(echo "$(adb shell su -c 'du -s '"$1"'' | cut -f1) * 1024" | bc)
    FNAME=data.tar.gz
  fi
  nc -d localhost 5555 |
    pv -s "$SIZE" | gzip -c >"$FNAME"
}
