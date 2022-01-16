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

PREPARE='
killall nc
rm /cache/fifo 2>/dev/null
mkfifo /cache/fifo
'

WITH_NC='nc -lp 5555 -e'

# setup port forwarding for netcat
forward_adb() {
  adb wait-for-device forward tcp:5555 tcp:5555
}

backup_tar() {
  (
  trap exit INT HUP TERM
  trap 'cat /tmp/send_backup*.pid | xargs kill -9 2>/dev/null; cat /tmp/send_backup_*.stderr >&2; rm /tmp/send_backup_*.*' EXIT
  send_backup_fifo > /tmp/send_backup_fifo.stdout 2>/tmp/send_backup_fifo.stderr &
  echo $! >/tmp/send_backup_fifo.pid
  sleep 1
  send_backup_nc > /tmp/send_backup_nc.stdout 2> /tmp/send_backup_nc.stderr &
  sleep 1
  echo $! >/tmp/send_backup_nc.pid
  receive_backup
)
}

send_backup_fifo() {
#   forward_adb
#   exec_standalone "
# $PREPARE
# cd / || exit
# tar -cvf /cache/fifo --exclude '*/Germany.bin' --exclude '*.obf' data/data/com.topjohnwu.magisk
# "
adb forward tcp:5555 tcp:5555
adb shell 'su -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh -c \"
killall nc 2>/dev/null
rm /cache/fifo 2>/dev/null
mkfifo /cache/fifo
tar -cvf /cache/fifo data/data/com.topjohnwu.magisk
\""'
}

send_backup_nc() {
#   forward_adb
#   exec_standalone "
# $WITH_NC gzip -c /cache/fifo
# "
adb forward tcp:5555 tcp:5555
adb shell 'su -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh -c \"
nc -l -p 5555 -e cat /cache/fifo
rm /cache/fifo 2>/dev/null
\""'
}

send_backup_raw() {
  forward_adb
  exec_standalone "
$PREPARE
$WITH_NC dd if=/dev/block/mmcblk0p59 bs=4k &
"
}

receive() {
  nc -d localhost 5555 |
    pv -s "$1" | gzip -c >"$2"
}

# PC: send tar data (tested with bsd-netcat)
receive_backup() {
  receive "$(echo "$(adb shell su -c 'du -s /data/data/com.topjohnwu.magisk' | cut -f1) * 1024" | bc)" data.tar.gz
}

receive_backup_raw() {
  # shellcheck disable=SC2016
  receive "$(adb shell 'su -c "awk '\''/mmcblk0p59/{print \$3 * 1024}'\'' < /proc/partitions"')" data.img.gz
}
