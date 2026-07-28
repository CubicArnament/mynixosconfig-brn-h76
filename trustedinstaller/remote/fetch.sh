#!/usr/bin/env sh
# trustedinstaller/remote/fetch.sh
#
# POSIX sh — детект дисков и камеры на целевой машине.
# Передаётся на целевую машину через SSH pipe:
#   ssh host "sh -s -- [disk-override] [camera-override]" < remote/fetch.sh
#
# Вывод: строки DISK|...|... и CAMERA|...
set -eu

find_disk_by_id() {
  disk_real="$1"
  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"; shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      case "$p" in
        /dev/disk/by-id/nvme-eui.*) printf "%s\n" "$p"; exit 0 ;;
      esac
    done; exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

find_disk_by_id_nvme() {
  disk_real="$1"
  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"; shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      case "$p" in
        /dev/disk/by-id/nvme-*) printf "%s\n" "$p"; exit 0 ;;
      esac
    done; exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

find_disk_by_id_any() {
  disk_real="$1"
  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"; shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      printf "%s\n" "$p"; exit 0
    done; exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

root_backing_disk() {
  root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  [ -n "$root_source" ] || return 0
  root_real=$(readlink -f "$root_source" 2>/dev/null || printf "%s" "$root_source")
  root_pkname=$(lsblk -ndo PKNAME "$root_real" 2>/dev/null | head -n 1 || true)
  if [ -n "$root_pkname" ]; then printf "/dev/%s\n" "$root_pkname"; return 0; fi
  root_type=$(lsblk -ndo TYPE "$root_real" 2>/dev/null | head -n 1 || true)
  [ "$root_type" = "disk" ] && printf "%s\n" "$root_real"
}

disk_mount_summary() {
  lsblk -nrpo PATH,MOUNTPOINT "$1" 2>/dev/null | awk '
    NF >= 2 && $2 != "" { printf "%s:%s;", $1, substr($0, index($0,$2)) }
  ' | sed 's/;$//'
}

disk_holder_summary() {
  lsblk -nrpo PATH "$1" 2>/dev/null | while IFS= read -r node; do
    [ -n "$node" ] || continue
    base=$(basename "$node")
    holder_dir="/sys/class/block/$base/holders"
    if [ -d "$holder_dir" ] && [ -n "$(ls -A "$holder_dir" 2>/dev/null || true)" ]; then
      holders=$(ls "$holder_dir" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
      printf "%s:%s;" "$node" "$holders"
    fi
  done | sed 's/;$//'
}

candidate_lines() {
  lsblk -dnpo PATH,TYPE,RM,RO,ROTA,TRAN,SIZE,MODEL 2>/dev/null | awk '
    NF >= 7 && $2=="disk" && $3=="0" && $4=="0" {
      path=$1; rota=$5; tran=$6; size=$7; model=""
      for(i=8;i<=NF;i++) {
        if (i == 8) model=$i
        else model = model " " $i
      }
      if(path~/\/dev\/(loop|zram|ram|fd|sr|md|dm-)/) next
      if (tran == "usb") next
      priority=0; class="unknown"
      if(path~/\/dev\/nvme[0-9]+n[0-9]+$/||tran=="nvme") { priority=300; class="nvme" }
      else if(rota=="0"&&(tran=="sata"||tran=="ata")) { priority=200; class="sata-ssd" }
      else if(rota=="0") { priority=150; class="solid-state" }
      else if(rota=="1") { priority=100; class="hdd" }
      printf "%s|%s|%s|%s|%s\n",priority,path,class,size,model
    }
  ' | sort -t"|" -k1,1nr -k2,2
}

emit_disk_candidates() {
  lines=$(candidate_lines)
  root_disk=$(root_backing_disk)
  if [ -z "$lines" ]; then printf "No internal non-USB disks found.\n" >&2; exit 2; fi

  printf "%s\n" "$lines" | while IFS='|' read -r priority path class size model; do
    [ -n "$path" ] || continue
    byid=$(find_disk_by_id "$path")
    [ -n "$byid" ] || byid=$(find_disk_by_id_nvme "$path")
    [ -n "$byid" ] || byid=$(find_disk_by_id_any "$path")
    [ -n "$byid" ] || continue

    mount_summary=$(disk_mount_summary "$path")
    holder_summary=$(disk_holder_summary "$path")
    root_backing=0; occupied=0; occupancy_reasons=""

    if [ -n "$mount_summary" ]; then
      occupied=1; occupancy_reasons="mountpoints"
    fi
    if [ -n "$holder_summary" ]; then
      occupied=1
      occupancy_reasons="${occupancy_reasons:+$occupancy_reasons,}holders"
    fi
    if [ -n "$root_disk" ] && [ "$path" = "$root_disk" ]; then
      root_backing=1; occupied=1
      occupancy_reasons="${occupancy_reasons:+$occupancy_reasons,}current-root"
    fi

    printf "DISK|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
      "$priority" "$byid" "$path" "$class" "$size" "$model" \
      "$occupied" "$root_backing" "$occupancy_reasons" \
      "$mount_summary" "$holder_summary"
  done
}

pick_camera() {
  if [ -n "${1:-}" ]; then printf "%s\n" "$1"; return 0; fi
  if [ -d /dev/v4l/by-id ]; then
    cam=$(find /dev/v4l/by-id -maxdepth 1 -type l -name "*video-index0" \
          ! -name "*IR*" ! -name "*ir*" | sort | head -n 1 || true)
    [ -n "$cam" ] && { printf "%s\n" "$cam"; return 0; }
  fi
  if [ -d /dev/v4l/by-path ]; then
    cam=$(find /dev/v4l/by-path -maxdepth 1 -type l -name "*video-index0" \
          | sort | head -n 1 || true)
    [ -n "$cam" ] && { printf "%s\n" "$cam"; return 0; }
  fi
  printf "\n"
}

DISK_OVERRIDE="${1:-}"
CAMERA_OVERRIDE="${2:-}"

if [ -n "$DISK_OVERRIDE" ]; then
  printf "DISK|override|%s|override|override|override|0|0|||\n" "$DISK_OVERRIDE"
else
  emit_disk_candidates
fi

printf "CAMERA|%s\n" "$(pick_camera "$CAMERA_OVERRIDE")"
