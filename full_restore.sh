#!/bin/sh

  DATE=${1:-$(date +%F)}
  
  # TODO: only works when executed from date folder
  cd /media/storage_ssd2/honor9_backups/"$DATE" || exit

. restore_utils &&
  install_magisk ../assets/com.topjohnwu.magisk_v7.5.1.apk ../assets/magisk_installs/Magisk-v20.4.zip &&
  install_magisk_modules ../assets &&
  adb wait-for-device shell 'su -c "echo >/dev/null"' &&
  install_apks apks &&
  prepare_tarball data.tar.gz data_restore.tar.gz &&
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
  echo "exit code is $ES."
  echo starting receive job
  [ "$EX" -eq 0 ] || exit
  echo "EX is $EX"
  restore data_restore.tar.gz true &&
  adb reboot &&
  echo waiting for device &&
  adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done' &&
  while ! adb shell "su -c 'echo'" >/dev/null 2>&1; do
    printf ' .'
    sleep 1
  done &&
  echo "device connected" &&
  post_install_permissions
