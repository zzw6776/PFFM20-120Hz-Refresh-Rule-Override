#!/system/bin/sh
MODDIR="${0%/*}"
. "$MODDIR/mount-refresh-config.sh"

log INFO "========== post-fs-data start =========="
apply_refresh_config_mount post-fs-data
log INFO "post-fs-data end: result=$?"
