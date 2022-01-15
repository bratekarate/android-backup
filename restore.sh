#!/bin/sh

trap exit QUIT INT HUP TERM
trap 'pkill -f "adb wait-for-device shell su -c \"ASH_STANDALONE"' EXIT

. restore_utils &&
  # TODO: only works when executed from date folder
  cd /media/storage_ssd2/honor9_backups/2022-01-12/ &&
  # install_apks apks &&
  # install_magisk apks/com.topjohnwu.magisk.apk ../assets &&
  prepare_tarball data.tar data_restore.tar &&
  sleep 5 &&
  adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  sleep 5 &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected"

  EX=$? 
  echo starting receive job
  [ "$EX" -eq 0 ] || exit
  receive_restore_backup >tar.log 2>&1 &

echo restore after 5 sec
sleep 5

. restore_utils && send_restore_backup data_restore.tar &&
  adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected" &&
  post_install_permissions
