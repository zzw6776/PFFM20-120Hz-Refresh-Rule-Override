#!/system/bin/sh
set -eu

STAGE=/data/local/tmp/global120hz
OLD_MOD=/data/adb/modules/global120hz
OLD_STATE=/data/adb/global120hz
OLD_FAKE=/dev/global120hz
OLD_BACKUPS=/data/adb/global120hz-backups
NEW_BACKUPS=/data/adb/pffm20_120hz_rr_override-backups

sh "$STAGE/install.sh"

if [ -d "$OLD_BACKUPS" ]; then
  mkdir -p "$NEW_BACKUPS"
  cp -a "$OLD_BACKUPS"/. "$NEW_BACKUPS"/ 2>/dev/null || true
fi

if [ -d "$OLD_MOD" ]; then
  rm -rf "$OLD_MOD"
fi

if [ -d "$OLD_STATE" ]; then
  rm -rf "$OLD_STATE"
fi

if [ -d "$OLD_FAKE" ]; then
  for d in "$OLD_FAKE"/*; do
    [ -d "$d" ] && umount "$d" 2>/dev/null || true
  done
  rm -rf "$OLD_FAKE" 2>/dev/null || true
fi

echo migrated=1
