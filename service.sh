#!/system/bin/sh
MODDIR="${0%/*}"
. "$MODDIR/mount-refresh-config.sh"

log INFO "========== service start =========="
apply_refresh_config_mount service
result=$?

settings put system peak_refresh_rate 120.0
settings put secure oplus_customize_screen_refresh_rate 3
settings put secure user_preferred_screen_index 3

log INFO "service end: result=$result"
exit "$result"
