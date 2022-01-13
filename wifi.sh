#!/bin/sh

# First tap through initial setup, use defaults. Just need access to magisk app to allow shell root.
# If adb debug is not enabled yet, do it now.

# install magisk
adb install apks/com.topjohnwu.magisk.apk

# do NOT proceed with magisk setup yet! press cancel if asked.

# configure wifi and reboot. magisk will prompt for shell access on phone. accept.
gpg -d WifiConfigStore.xml.gpg >/tmp/WifiConfigStore.xml && for CFG in /tmp/WifiConfigStore.xml WifiConfigStore.xml.encrypted-checksum; do adb push "$CFG" /sdcard; done && rm /tmp/WifiConfigStore.xml && adb shell "su -c 'cd /data/misc/wifi && mv WifiConfigStore.xml WifiConfigStore.xml.bak && mv /sdcard/WifiConfigStore.xml* . && chown 1000:1000 WifiConfigStore.xml*'" && adb shell "su -c 'rm /sdcard/WifiConfigStore.xml*'" && adb reboot

# setup correct magisk channel
adb shell "su -c \"sed 's|\(custom_channel.*>\).*\(<\)|\1https://raw.githubusercontent.com/topjohnwu/magisk_files/63555595ffa9b079f3a411dd2c00a80a3d985ccc/stable.json\2|g' /data/user_de/0/com.topjohnwu.magisk/shared_prefs/com.topjohnwu.magisk_preferences.xml\""

# restart magisk on the phone. accept the offer to complete installation now. the phone will reboot after.

# install apks from backup
(cd apks && find . ! -name . -prune -name '*.apk' | while IFS= read -r L; do adb install "$L" & done) && trap 'pkill -f "adb install "' INT && { while pgrep -f 'adb install ' >/dev/null; do sleep 1; done; trap - INT; } &&
  # prepare the tarball to restore userdata
  adb shell 'su -c "cat /data/system/packages.list"' > packages.list &&  { sudo rm -rf data; sudo tar -xf data.tar data/system/users data/system/notification_policy.xml data/data; } && (cd data/data && sudo find . ! -name . -prune) | sed 's|^./\(.*\)|\1|g' | while IFS= read -r L; do APPID=$(awk -v pkg="$L" '$0 ~ "^"pkg" " {print $2}' packages.list); sudo chown -R "$APPID:$APPID" data/data/"$L" || echo "$L"; done && sudo rm data_data.tar && sudo tar -cf data_data.tar data &&
# allow fluidng to hide the navbar
adb shell pm grant com.fb.fluid android.permission.WRITE_SECURE_SETTINGS


# setup port forwarding for netcat
adb forward tcp:5555 tcp:5555

# 2 ADB shells and one host shell are needed for the data restoration

# ADB shell 1: create pipe, clean up if necessary
su
rm /cache/fifo 2>/dev/null; mkfifo /cache/fifo
cd / && /data/adb/magisk/busybox tar -xvf /cache/fifo

# ADB shell 2: receive data, send to pipe
su
/data/adb/magisk/busybox nc -lp 5555 > /cache/fifo

# PC: send tar data (tested with bsd-netcat)
pv data_data.tar | nc -q1 localhost 5555

# finally, reboot the device
adb reboot
