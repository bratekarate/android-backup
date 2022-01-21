#!/bin/sh

exec_adb_shell() {
  adb wait-for-device shell "su -c '$1'"
}

exec_adb_shell_fw() {
  adb wait-for-device forward tcp:5555 tcp:5555
  exec_adb_shell "$1"
}

# install apks from backup. Let it run in the background with other shell or job management
install_apks() {
  (
    cd "$1" && find . ! -name . -prune -type d |
      xargs -n1 sh -c 'adb wait-for-device install-multiple "$1"/*.apk' _
  )
}

# install magisk manually and reboot
install_magisk() {
  adb wait-for-device install "$1" &&
    unzip -o "$2" META-INF/com/google/android/update-binary
  for FILE in "$2" META-INF/com/google/android/update-binary; do
    adb push "$FILE" /sdcard/Download
  done
  rm -r META-INF
  exec_adb_shell '
  cd /sdcard/Download &&
  BOOTMODE=true sh update-binary dummy 1 Magisk-v20.4.zip &&
  rm -rf update-binary
'
}

install_magisk_modules() {
  # TODO: prevent duplicate magisk installation. works for now.
  (cd "$1"/magisk_mods && for MOD in *.zip; do
    adb wait-for-device push "$MOD" /sdcard/Download &&
      exec_adb_shell 'ASH_STANDALONE=1 BOOTMODE=true ZIPFILE=/sdcard/Download/'"$MOD"' OUTFD=1 /data/adb/magisk/busybox sh -c "
  . /data/adb/magisk/util_functions.sh
  install_module
"'
  done)
}

# old way: do phone initial setup, setup correct magisk channel and install magisk via net installer.
# TODO: DOES NOT WORK IF NO CHANNEL IS CONFIGURED!
#adb wait-for-device shell "su -c \"sed -i 's|\(custom_channel.*>\).*\(<\)|\1https://raw.githubusercontent.com/topjohnwu/magisk_files/63555595ffa9b079f3a411dd2c00a80a3d985ccc/stable.json\2|g' /data/user_de/0/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml\""

fix_perms() {
  (
    cd "$(dirname "$1")" && shift &&
      for DIR in "$@"; do
        (cd data/"$DIR" && find . ! -name . -prune) |
          sed 's|^./\(.*\)|\1|g' |
          while IFS= read -r L; do
            APPID=$(awk -v pkg="$L" '$0 ~ "^"pkg" " {print $2}' packages.list)
            chown -R "$APPID:$APPID" data/"$DIR"/"$L" || echo "$L"
          done
      done
  )
}

# prepare the tarball to restore userdata
prepare_tarball() {
  (
    cd "$(dirname "$1")" &&
      adb wait-for-device shell \
        'su -c "cat /data/system/packages.list"' >packages.list && {
      rm -r data
      echo "extracting tar '$1'" >&2
      pv "$1" | gzip -d -c | tar -x \
        data/system/users \
        data/system_ce \
        data/system_de \
        data/user_de \
        data/data \
        data/media/0 \
        data/misc/wifi \
        data/misc/dhcp \
        data/misc/vpn \
        data/misc/bluetooth \
        data/misc/bluedroid \
        data/misc/radio \
        data/misc/profiles
    } &&
      echo fixing permissions >&2
    fix_perms data data user_de/0 misc/profiles/cur/0 misc/profiles/ref &&
      echo "building tar '$2'" >&2 &&
      tar -c data | pv -s "$(du -sb data | cut -f1)" | gzip -c >"$2"
  )
}

cleanup_postrestore() {
  DEBUG=${1:-false}
  cat /tmp/receive_restore$$*.pid | xargs kill -9 2>/dev/null
  "$DEBUG" && cat /tmp/receive_restore$$_*.stdout
  cat /tmp/receive_restore$$_*.stderr >&2
  rm /tmp/receive_restore$$_*.*
  exit 0
}

restore() {
  (
    trap exit INT HUP TERM
    trap 'cleanup_postrestore "$2"' EXIT
    receive_restore_fifo >/tmp/receive_restore$$_fifo.stdout 2>/tmp/receive_restore$$_fifo.stderr &
    echo $! >/tmp/receive_restore$$_fifo.pid
    sleep 1
    receive_restore_nc >/tmp/receive_restore$$_nc.stdout 2>/tmp/receive_restore$$_nc.stderr &
    sleep 1
    echo $! >/tmp/receive_restore$$_nc.pid
    send_restore "$1"
  )
}

# ADB: prepare to receive tar data
receive_restore_fifo() {
  # setup port forwarding for netcat
  exec_adb_shell_fw '
busybox rm /cache/fifo 2>/dev/null
busybox mkfifo /cache/fifo
cd / && busybox tar -xvf /cache/fifo \
  --exclude="data/data/im.vector.app/files/*" \
  --exclude="data/data/im.vector.app/shared_prefs/im.vector.matrix.android.keys.xml" \
  --exclude="data/data/dev.msfjarvis.aps/shared_prefs/http_proxy.xml" \
  --exclude="data/data/dev.msfjarvis.aps/shared_prefs/git_operation.xml"
'
}

receive_restore_nc() {
  exec_adb_shell_fw '
killall nc 2>/dev/null
tail -f /dev/null | busybox nc -lp 5555 >/cache/fifo
busybox rm /cache/fifo 2>/dev/null
'
}

# PC: send tar data (tested with bsd-netcat)
send_restore() {
  pv "$1" | gzip -dc | nc -N localhost 5555 &&
    exec_adb_shell 'busybox pkill -f "busybox nc -lp "'
  pkill -KILL -f 'adb.*nc -lp '
}

# hide the navbar
post_install_permissions() {
  adb wait-for-device shell '
settings put global navigationbar_is_min 1
wm overscan 0,0,0,-140
'
}
