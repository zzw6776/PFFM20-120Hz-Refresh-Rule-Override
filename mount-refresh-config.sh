#!/system/bin/sh

STATE_DIR=/data/adb/pffm20_120hz_rr_override
FAKE_ROOT=/dev/pffm20_120hz_rr_override
LOG_FILE="$STATE_DIR/module.log"
MOUNTS_FILE="$STATE_DIR/mounts.tsv"
TARGET=/my_product/etc/refresh_rate_config.xml
SOURCE_CONFIG="$MODDIR/files/refresh_rate_config.xml"

mkdir -p "$STATE_DIR" 2>/dev/null
chmod 0700 "$STATE_DIR" 2>/dev/null

log() {
  printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$LOG_FILE"
}

is_exact_mountpoint() {
  awk -v target="$1" '$5 == target { found=1 } END { exit !found }' /proc/self/mountinfo 2>/dev/null
}

unmount_exact() {
  local target="$1"
  is_exact_mountpoint "$target" || return 0
  umount "$target" 2>/dev/null || umount -l "$target" 2>/dev/null || return 1
  ! is_exact_mountpoint "$target"
}

get_context() {
  ls -Zd "$1" 2>/dev/null | awk '{print $1}'
}

apply_refresh_config_mount() {
  local stage="$1" target_context fake_dir fake_file source_context
  [ -f "$SOURCE_CONFIG" ] || { log ERROR "$stage missing source config: $SOURCE_CONFIG"; return 1; }
  [ -f "$TARGET" ] || { log ERROR "$stage missing target config: $TARGET"; return 1; }

  target_context="$(get_context "$TARGET")"
  [ -n "$target_context" ] || { log ERROR "$stage cannot read target SELinux context"; return 1; }

  unmount_exact "$TARGET" || {
    log ERROR "$stage cannot unmount existing target mount: $TARGET"
    return 1
  }

  rm -rf "$FAKE_ROOT" 2>/dev/null
  mkdir -p "$FAKE_ROOT" 2>/dev/null || return 1
  chown 0:0 "$FAKE_ROOT" 2>/dev/null
  chmod 0700 "$FAKE_ROOT" 2>/dev/null

  fake_dir="$FAKE_ROOT/ctx_system_file"
  mkdir -p "$fake_dir" 2>/dev/null || return 1
  mount -t tmpfs -o "size=1m,mode=0700" tmpfs "$fake_dir" 2>/dev/null || {
    log ERROR "$stage tmpfs mount failed: $fake_dir"
    return 1
  }
  chcon "$target_context" "$fake_dir" 2>/dev/null || {
    log ERROR "$stage tmpfs chcon failed: $fake_dir context=$target_context"
    umount "$fake_dir" 2>/dev/null
    return 1
  }

  fake_file="$fake_dir/refresh_rate_config.xml"
  cp -a "$SOURCE_CONFIG" "$fake_file" 2>/dev/null || {
    log ERROR "$stage copy fake config failed"
    umount "$fake_dir" 2>/dev/null
    return 1
  }
  chown 0:0 "$fake_file" 2>/dev/null
  chmod 0444 "$fake_file" 2>/dev/null
  chcon "$target_context" "$fake_file" 2>/dev/null || {
    log ERROR "$stage fake config chcon failed: $fake_file context=$target_context"
    umount "$fake_dir" 2>/dev/null
    return 1
  }

  source_context="$(get_context "$fake_file")"
  [ "$source_context" = "$target_context" ] || {
    log ERROR "$stage fake config context mismatch expected=$target_context actual=$source_context"
    umount "$fake_dir" 2>/dev/null
    return 1
  }

  mount --bind "$fake_file" "$TARGET" 2>/dev/null || mount -o bind "$fake_file" "$TARGET" 2>/dev/null || {
    log ERROR "$stage bind mount failed: $fake_file -> $TARGET"
    umount "$fake_dir" 2>/dev/null
    return 1
  }

  printf '%s\t%s\n' "$TARGET" "$fake_file" > "$MOUNTS_FILE"
  log INFO "$stage mounted $fake_file -> $TARGET context=$target_context"
  return 0
}
