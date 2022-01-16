#!/bin/sh

trap exit QUIT INT HUP TERM
trap 'pkill -f "adb wait-for-device shell su -c \"ASH_STANDALONE"' EXIT

  # TODO: only works when executed from date folder
  cd /media/storage_ssd2/honor9_backups/"$1"/ || exit

# . restore_utils &&
#   install_apks apks &&
#   install_magisk apks/com.topjohnwu.magisk.apk ../assets &&
#   prepare_tarball data.tar.gz data_restore.tar.gz &&
#   sleep 5 &&
#   adb reboot &&
#   echo waiting for device &&
#   adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
#   sleep 5 &&
#   while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
#     printf ' .'
#     sleep 1
#   done &&
#   echo "device connected"

  # EX=$?
  # echo "exit code is $ES."
  # echo starting receive job
  # [ "$EX" -eq 0 ] || exit
  # echo "EX is $EX"
  . restore_utils && receive_restore_backup >tar.log 2>&1 &

echo restore after 5 sec
sleep 5

. restore_utils && send_restore_backup data_restore.tar.gz &&
  adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected" &&
  post_install_permissions
