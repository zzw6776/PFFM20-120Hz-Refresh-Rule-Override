#!/system/bin/sh
set -e

MODID=pffm20_120hz_rr_override
STAGE=/data/local/tmp/global120hz
MODDIR=/data/adb/modules/$MODID
BACKUPDIR=/data/adb/pffm20_120hz_rr_override-backups
TARGET=/my_product/etc/refresh_rate_config.xml
SOURCE=$MODDIR/files/refresh_rate_config.xml
TS=$(date +%Y%m%d-%H%M%S)

is_exact_mountpoint() {
  awk -v target="$1" '$5 == target { found=1 } END { exit !found }' /proc/self/mountinfo 2>/dev/null
}

unmount_exact() {
  local target="$1"
  is_exact_mountpoint "$target" || return 0
  umount "$target" 2>/dev/null || umount -l "$target" 2>/dev/null
  is_exact_mountpoint "$target" && sleep 1
  ! is_exact_mountpoint "$target"
}

generate_refresh_config() {
  local input="$1" output="$2" tmp="$2.tmp"
  awk '
    function rewrite_rate_ids(line, output, token, rate, parts, replacement) {
      while (match(line, /rateId="[0-3]-[0-3]-[0-3]-[0-3]"/)) {
        token = substr(line, RSTART, RLENGTH)
        rate = substr(token, 9, 7)
        split(rate, parts, "-")
        replacement = "rateId=\"" parts[1] "-" parts[2] "-" parts[3] "-3\""
        output = output substr(line, 1, RSTART - 1) replacement
        line = substr(line, RSTART + RLENGTH)
      }
      return output line
    }

    function set_attr(line, name, value, pattern, replacement) {
      pattern = name "=\"[^\"]*\""
      replacement = name "=\"" value "\""
      if (line ~ pattern) {
        sub(pattern, replacement, line)
      } else {
        sub(/[[:space:]]*\/>/, " " replacement " />", line)
      }
      sub(/[[:space:]]+\/>/, " />", line)
      return line
    }

    {
      line = rewrite_rate_ids($0)
      if (line ~ /<item[[:space:]>]/ && line ~ /\/>/) {
        line = set_attr(line, "disableViewOverride", "true")
      }
      if (line ~ /<config[[:space:]>]/ && line ~ /\/>/) {
        config_seen = 1
        line = set_attr(line, "enableRateOverride", "true")
        line = set_attr(line, "inputMethodLowRate", "false")
        line = set_attr(line, "enableFodHighRate", "true")
      }
      if (line ~ /<\/refresh_rate_config>/ && !config_seen) {
        print "  <config enableRateOverride=\"true\" inputMethodLowRate=\"false\" enableFodHighRate=\"true\" />"
        config_seen = 1
      }
      print line
    }
  ' "$input" > "$tmp"

  [ -s "$tmp" ] || return 1
  grep -q '<refresh_rate_config' "$tmp" || return 1
  grep -q 'inputMethodLowRate="false"' "$tmp" || return 1
  mv "$tmp" "$output"
}

mkdir -p "$BACKUPDIR" "$MODDIR/files"
unmount_exact "$TARGET"
cp -a "$TARGET" "$BACKUPDIR/refresh_rate_config.xml.$TS"
cp -a "$STAGE/module.prop" "$MODDIR/module.prop"
cp -a "$STAGE/mount-refresh-config.sh" "$MODDIR/mount-refresh-config.sh"
cp -a "$STAGE/post-fs-data.sh" "$MODDIR/post-fs-data.sh"
cp -a "$STAGE/service.sh" "$MODDIR/service.sh"
generate_refresh_config "$TARGET" "$SOURCE"

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
