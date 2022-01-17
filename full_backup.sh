#!/bin/sh

  DATE=${1:-$(date +%F)}

  # TODO: only works when executed from date folder
  cd /media/storage_ssd2/honor9_backups/"$DATE"/ || exit

. backup_utils &&
  backup_apks &&
  backup /data
