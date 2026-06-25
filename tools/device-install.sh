#!/system/bin/sh
set -e

MODID=pffm20_120hz_rr_override
STAGE=/data/local/tmp/global120hz
MODDIR=/data/adb/modules/$MODID
BACKUPDIR=/data/adb/pffm20_120hz_rr_override-backups
TARGET=/my_product/etc/refresh_rate_config.xml
SOURCE=$MODDIR/files/refresh_rate_config.xml
TS=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUPDIR" "$MODDIR/files"
cp -a "$TARGET" "$BACKUPDIR/refresh_rate_config.xml.$TS"
cp -a "$STAGE/module.prop" "$MODDIR/module.prop"
cp -a "$STAGE/mount-refresh-config.sh" "$MODDIR/mount-refresh-config.sh"
cp -a "$STAGE/post-fs-data.sh" "$MODDIR/post-fs-data.sh"
cp -a "$STAGE/service.sh" "$MODDIR/service.sh"
cp -a "$STAGE/files/refresh_rate_config.xml" "$SOURCE"

chmod 0644 "$MODDIR/module.prop" "$MODDIR/mount-refresh-config.sh" "$SOURCE"
chmod 0755 "$MODDIR/post-fs-data.sh" "$MODDIR/service.sh"
chown -R 0:0 "$MODDIR" "$BACKUPDIR"

if sh "$MODDIR/service.sh"; then
  MOUNTED=1
else
  MOUNTED=0
fi

echo "backup=$BACKUPDIR/refresh_rate_config.xml.$TS"
echo "module=$MODDIR"
echo "mounted_now=$MOUNTED"
