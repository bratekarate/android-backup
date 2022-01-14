#!/bin/sh

# install apks from backup. Let it run in the background with other shell or job management
install_apks() {
  (cd apks && find . ! -name . -prune -name '*.apk' | while IFS= read -r L; do adb install "$L" & done) && trap 'pkill -f "adb install "' INT && { while pgrep -f 'adb install ' >/dev/null; do sleep 1; done; trap - INT; }
}

# install magisk manually and reboot
install_magisk() {
  adb install apks/com.topjohnwu.magisk.apk &&
  adb push Magisk-v.20.4.zip /sdcard/Download &&
  adb shell 'su -c "cd /sdcard/Download && mkdir -p tmp_magisk && unzip -d tmp_magisk Magisk-v20.4.zip && mkdir -p tmp_install && cp tmp_magisk/META-INF/com/google/android/update* tmp_install && (cd tmp_install && cp ../Magisk-v20.4.zip install.zip && BOOTMODE=true sh update-binary dummy 1 install.zip); rm -r tmp_install tmp_magisk"' &&
  adb reboot
}

# old way: do phone initial setup, setup correct magisk channel and install magisk via net installer.
# TODO: DOES NOT WORK IF NO CHANNEL IS CONFIGURED!
#adb shell "su -c \"sed -i 's|\(custom_channel.*>\).*\(<\)|\1https://raw.githubusercontent.com/topjohnwu/magisk_files/63555595ffa9b079f3a411dd2c00a80a3d985ccc/stable.json\2|g' /data/user_de/0/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml\""

fix_perms() {
  for DIR in "$@"; do
    (cd data/"$DIR" && sudo find . ! -name . -prune) | sed 's|^./\(.*\)|\1|g' | while IFS= read -r L; do
      APPID=$(awk -v pkg="$L" '$0 ~ "^"pkg" " {print $2}' packages.list)
      sudo chown -R "$APPID:$APPID" data/"$DIR"/"$L" || echo "$L"
    done
  done
}

# prepare the tarball to restore userdata
prepare_tarball() {
  adb shell 'su -c "cat /data/system/packages.list"' > packages.list &&  { sudo rm -rf data; sudo tar -xf data_stripped_large.tar data/system/users data/system_ce data/system_de data/user_de data/data data/media/0 data/misc/wifi data/misc/dhcp data/misc/vpn data/misc/bluetooth data/misc/bluedroid data/misc/radio data/misc/profiles; } && fix_perms data user_de/0 misc/profiles/cur/0 misc/profiles/ref && sudo rm data_restore.tar && sudo tar -cf data_restore.tar data
}

# ADB: prepare to receive tar data
receive_restore_backup() {
# setup port forwarding for netcat
adb forward tcp:5555 tcp:5555
adb shell 'su -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh -c \"rm /cache/fifo 2>/dev/null; mkfifo /cache/fifo && cd / && tar -xvf /cache/fifo & nc -lp 5555 >/cache/fifo\""'
}

# PC: send tar data (tested with bsd-netcat)
send_restore_backup() {
  pv dataestore.tar | nc -q1 localhost 5555
}

# reboot the device
# adb reboot

# allow fluidng to hide the navbar
post_install_permissions() {
  adb shell pm grant com.fb.fluid android.permission.WRITE_SECURE_SETTINGS
}

# perform other permission settings, or similar
