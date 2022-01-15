#!/bin/sh

# TODO: only works when executed from date folder
cd /media/storage_ssd2/honor9_backups/2022-01-12/ &&
  . ../scripts/install_utils.sh &&
  install_apks >apk_out.log &
install_magisk &&
  EX=$? &&
  wait &&
  sudo su -c '. ../scripts/install_utils.sh && prepare_tarball &'
sleep 5
[ "$EX" -eq 0 ] && adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  sleep 5 &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected" &&
  receive_restore_backup >tar.log 2>&1 &
sleep 5 &&
  send_restore_backup &&
  adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected" &&
  post_install_permissions
