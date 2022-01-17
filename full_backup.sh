#!/bin/sh

  DATE=${1:-$(date +%F)}

  # TODO: only works when executed from date folder
  mkdir -p /media/storage_ssd2/honor9_backups/"$DATE"/ &&
  cd /media/storage_ssd2/honor9_backups/"$DATE"/ || exit

. backup_utils &&
  backup_apks &&
  backup /data
