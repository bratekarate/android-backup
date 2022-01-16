#!/bin/sh

# install apks from backup. Let it run in the background with other shell or job management
install_apks() {
  (
    cd "$1" && find . ! -name . -prune -name '*.apk' |
      while IFS= read -r L; do
        adb wait-for-device install "$L"
      done
  )
}

# install magisk manually and reboot
install_magisk() {
  adb wait-for-device install "$1" &&
    # TODO: prevent duplicate magisk installation. works for now.
    (cd "$2" && for MOD in Magisk-v20.4.zip *.zip; do
      adb wait-for-device push "$MOD" /sdcard/Download &&
        adb wait-for-device shell '
su -c "ASH_STANDALONE=1 BOOTMODE=true ZIPFILE=/sdcard/Download/"'"$MOD"'" OUTFD=1 /data/adb/magisk/busybox sh -c \"
  echo "$ASH_STANDALONE"
  echo "$ZIPFILE"
  echo "$OUTFD"
  echo "$BOOTODE"
  . /data/adb/magisk/util_functions.sh
  install_module
\""'
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
      fix_perms data data user_de/0 misc/profiles/cur/0 misc/profiles/ref &&
      rm "$2" &&
      echo "building tar '$2'" >&2 &&
      tar -c data | pv -s "$(du -sb data | cut -f1)" | gzip -c > "$2" 
  )
}

# ADB: prepare to receive tar data
receive_restore_backup() {
  # setup port forwarding for netcat
  adb wait-for-device forward tcp:5555 tcp:5555
  adb wait-for-device shell 'su -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh -c \"
killall nc
rm /cache/fifo 2>/dev/null
mkfifo /cache/fifo
cd / && tar -xvf /cache/fifo &
tail -f /dev/null | nc -lp 5555  >/cache/fifo &
\""'
}

# PC: send tar data (tested with bsd-netcat)
send_restore_backup() {
  pv "$1" | nc -q5 localhost 5555
}

# reboot the device
# adb wait-for-device reboot

# allow fluidng to hide the navbar
post_install_permissions() {
  adb wait-for-device shell "
settings put global navigationbar_is_min 1
wm overscan 0,0,0,-140
"
}

# perform other permission settings, or similar
