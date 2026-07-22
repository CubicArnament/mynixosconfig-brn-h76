#!/usr/bin/env sh
set -eu

HOST="${1:-}"
OUT="${2:-hosts/honor-magicbook-x16-pro/local-device-paths.nix}"
DISK_OVERRIDE="${3:-}"
CAMERA_OVERRIDE="${4:-}"
INSTALL_DISK_FILTER="${INSTALL_DISK_FILTER:-}"
INSTALL_DISK_INDEX="${INSTALL_DISK_INDEX:-}"

if [ -z "$HOST" ]; then
  echo "usage: $0 <ssh-target> [output-file] [disk-by-id] [camera-by-id-or-by-path]" >&2
  echo "env overrides: INSTALL_DISK_FILTER=<substring-or-class> INSTALL_DISK_INDEX=<n>" >&2
  exit 1
fi

remote_detect=$(cat <<'REMOTE_EOF'
set -eu

find_disk_by_id() {
  disk_real="$1"

  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"
    shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      case "$p" in
        /dev/disk/by-id/nvme-eui.*) echo "$p"; exit 0 ;;
      esac
    done
    exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

find_disk_by_id_nvme() {
  disk_real="$1"

  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"
    shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      case "$p" in
        /dev/disk/by-id/nvme-*) echo "$p"; exit 0 ;;
      esac
    done
    exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

find_disk_by_id_any() {
  disk_real="$1"

  find /dev/disk/by-id -maxdepth 1 -type l ! -name "*-part*" -exec sh -c '
    real="$1"
    shift
    for p do
      target=$(readlink -f "$p" 2>/dev/null || true)
      [ "$target" = "$real" ] || continue
      echo "$p"
      exit 0
    done
    exit 1
  ' sh "$disk_real" {} + 2>/dev/null | head -n 1
}

root_backing_disk() {
  root_source=$(findmnt -n -o SOURCE / 2>/dev/null || true)
  [ -n "$root_source" ] || return 0

  root_real=$(readlink -f "$root_source" 2>/dev/null || printf "%s\n" "$root_source")
  root_pkname=$(lsblk -ndo PKNAME "$root_real" 2>/dev/null | head -n 1 || true)

  if [ -n "$root_pkname" ]; then
    printf "/dev/%s\n" "$root_pkname"
    return 0
  fi

  root_type=$(lsblk -ndo TYPE "$root_real" 2>/dev/null | head -n 1 || true)
  if [ "$root_type" = "disk" ]; then
    printf "%s\n" "$root_real"
  fi
}

disk_mount_summary() {
  disk_real="$1"

  lsblk -nrpo PATH,MOUNTPOINT "$disk_real" 2>/dev/null | awk '
    NF >= 2 && $2 != "" {
      mountpoint = substr($0, index($0, $2))
      printf "%s:%s;", $1, mountpoint
    }
  ' | sed 's/;$//'
}

disk_holder_summary() {
  disk_real="$1"

  lsblk -nrpo PATH "$disk_real" 2>/dev/null | while IFS= read -r node; do
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
    $2 == "disk" && $3 == "0" && $4 == "0" && $6 != "usb" {
      path = $1
      rota = $5
      tran = $6
      size = $7
      model = ""
      for (i = 8; i <= NF; i++) {
        model = model (i == 8 ? "" : " ") $i
      }

      if (path ~ /\/dev\/(loop|zram|ram|fd|sr|md|dm-)/) {
        next
      }

      priority = 0
      class = "unknown"
      if (path ~ /\/dev\/nvme[0-9]+n[0-9]+$/ || tran == "nvme") {
        priority = 300
        class = "nvme"
      } else if (rota == "0" && (tran == "sata" || tran == "ata")) {
        priority = 200
        class = "sata-ssd"
      } else if (rota == "0") {
        priority = 150
        class = "solid-state"
      } else if (rota == "1") {
        priority = 100
        class = "hdd"
      }

      printf "%s|%s|%s|%s|%s\n", priority, path, class, size, model
    }
  ' | sort -t "|" -k1,1nr -k2,2
}

emit_disk_candidates() {
  lines=$(candidate_lines)
  root_disk=$(root_backing_disk)

  if [ -z "$lines" ]; then
    echo "No internal non-USB disks found on remote host." >&2
    exit 2
  fi

  printf "%s\n" "$lines" | while IFS='|' read -r priority path class size model; do
    [ -n "$path" ] || continue

    byid=$(find_disk_by_id "$path")
    if [ -z "$byid" ]; then
      byid=$(find_disk_by_id_nvme "$path")
    fi
    if [ -z "$byid" ]; then
      byid=$(find_disk_by_id_any "$path")
    fi
    [ -n "$byid" ] || continue

    mount_summary=$(disk_mount_summary "$path")
    holder_summary=$(disk_holder_summary "$path")
    root_backing=0
    occupied=0
    occupancy_reasons=""

    if [ -n "$mount_summary" ]; then
      occupied=1
      occupancy_reasons="mountpoints"
    fi

    if [ -n "$holder_summary" ]; then
      occupied=1
      if [ -n "$occupancy_reasons" ]; then
        occupancy_reasons="$occupancy_reasons,holders"
      else
        occupancy_reasons="holders"
      fi
    fi

    if [ -n "$root_disk" ] && [ "$path" = "$root_disk" ]; then
      root_backing=1
      occupied=1
      if [ -n "$occupancy_reasons" ]; then
        occupancy_reasons="$occupancy_reasons,current-root"
      else
        occupancy_reasons="current-root"
      fi
    fi

    printf "DISK|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
      "$priority" "$byid" "$path" "$class" "$size" "$model" \
      "$occupied" "$root_backing" "$occupancy_reasons" "$mount_summary" "$holder_summary"
  done
}

pick_camera() {
  if [ -n "${1:-}" ]; then
    printf "%s\n" "$1"
    return 0
  fi

  if [ -d /dev/v4l/by-id ]; then
    camera_by_id=$(find /dev/v4l/by-id -maxdepth 1 -type l -name "*video-index0" ! -name "*IR*" ! -name "*ir*" | sort | head -n 1 || true)
    if [ -n "$camera_by_id" ]; then
      printf "%s\n" "$camera_by_id"
      return 0
    fi
  fi

  if [ -d /dev/v4l/by-path ]; then
    camera_by_path=$(find /dev/v4l/by-path -maxdepth 1 -type l -name "*video-index0" | sort | head -n 1 || true)
    if [ -n "$camera_by_path" ]; then
      printf "%s\n" "$camera_by_path"
      return 0
    fi
  fi

  printf "\n"
}

if [ -n "${1:-}" ]; then
  printf "DISK|override|%s|override|override|override|user-selected\n" "$1"
else
  emit_disk_candidates
fi

printf "CAMERA|%s\n" "$(pick_camera "$2")"
REMOTE_EOF
)

RESULT=$(ssh "$HOST" "sh -s -- '$DISK_OVERRIDE' '$CAMERA_OVERRIDE'" <<EOF
$remote_detect
EOF
)

DISK_LINES=$(printf "%s\n" "$RESULT" | grep '^DISK|' || true)
CAMERA=$(printf "%s\n" "$RESULT" | awk -F'|' '/^CAMERA\|/ { sub(/^CAMERA\|/, "", $0); print; exit }')

if [ -z "$DISK_LINES" ]; then
  echo "No usable /dev/disk/by-id candidates were detected on target host." >&2
  exit 2
fi

ORIGINAL_DISK_COUNT=$(printf "%s\n" "$DISK_LINES" | sed '/^$/d' | wc -l)

OCCUPANCY_FILTER_APPLIED=0

if [ -n "$INSTALL_DISK_FILTER" ] && [ -z "$DISK_OVERRIDE" ]; then
  FILTER_KIND=$(printf "%s" "$INSTALL_DISK_FILTER" | tr '[:upper:]' '[:lower:]')

  case "$FILTER_KIND" in
    system|root)
      FILTERED_DISK_LINES=$(printf "%s\n" "$DISK_LINES" | awk -F'|' '$9 == "1"')
      ;;
    *)
      FILTERED_DISK_LINES=$(printf "%s\n" "$DISK_LINES" | awk -F'|' -v needle="$INSTALL_DISK_FILTER" '
        BEGIN {
          needle_l = tolower(needle)
        }
        {
          line_l = tolower($0)
          class_l = tolower($5)
          model_l = tolower($7)
          byid_l = tolower($3)
          if (class_l == needle_l || index(line_l, needle_l) > 0 || index(model_l, needle_l) > 0 || index(byid_l, needle_l) > 0) {
            print $0
          }
        }
      ')
      ;;
  esac

  if [ -z "$FILTERED_DISK_LINES" ]; then
    echo "INSTALL_DISK_FILTER=$INSTALL_DISK_FILTER did not match any install disk candidates on $HOST." >&2
    exit 2
  fi

  DISK_LINES="$FILTERED_DISK_LINES"
fi

if [ -z "$DISK_OVERRIDE" ]; then
  UNOCCUPIED_DISK_LINES=$(printf "%s\n" "$DISK_LINES" | awk -F'|' '$8 == "0"')
  if [ -n "$UNOCCUPIED_DISK_LINES" ]; then
    FILTER_KIND=$(printf "%s" "$INSTALL_DISK_FILTER" | tr '[:upper:]' '[:lower:]')
    if [ "$FILTER_KIND" != "system" ] && [ "$FILTER_KIND" != "root" ]; then
      DISK_LINES="$UNOCCUPIED_DISK_LINES"
      OCCUPANCY_FILTER_APPLIED=1
    fi
  fi
fi

DISK_COUNT=$(printf "%s\n" "$DISK_LINES" | sed '/^$/d' | wc -l)
SELECTED_LINE=$(printf "%s\n" "$DISK_LINES" | sed -n '1p')
AUTO_SELECTED=1
USER_SELECTED=0
INTERACTIVE_TTY=0
SELECTION_SOURCE="single-candidate"

if [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
  INTERACTIVE_TTY=1
fi

if [ "$DISK_COUNT" -gt 1 ]; then
  if [ "$INTERACTIVE_TTY" -eq 1 ]; then
    SELECTION_SOURCE="auto-timeout-or-default"
  else
    SELECTION_SOURCE="auto-noninteractive"
  fi
fi

if [ -n "$DISK_OVERRIDE" ]; then
  AUTO_SELECTED=0
  USER_SELECTED=1
  SELECTION_SOURCE="explicit-override"
elif [ -n "$INSTALL_DISK_INDEX" ]; then
  if ! printf "%s" "$INSTALL_DISK_INDEX" | grep -Eq '^[1-9][0-9]*$'; then
    echo "INSTALL_DISK_INDEX must be a positive integer starting from 1." >&2
    exit 2
  fi

  PICKED=$(printf "%s\n" "$DISK_LINES" | sed -n "${INSTALL_DISK_INDEX}p")
  if [ -z "$PICKED" ]; then
    echo "INSTALL_DISK_INDEX=$INSTALL_DISK_INDEX is out of range for $DISK_COUNT candidate(s)." >&2
    exit 2
  fi

  SELECTED_LINE="$PICKED"
  AUTO_SELECTED=0
  USER_SELECTED=1
  SELECTION_SOURCE="env-disk-index"
elif [ "$DISK_COUNT" -gt 1 ] && [ "$INTERACTIVE_TTY" -eq 1 ]; then
  echo "Multiple install disk candidates found on $HOST:" > /dev/tty
  n=1
  printf "%s\n" "$DISK_LINES" | while IFS='|' read -r _ priority byid path class size model; do
    printf "  [%s] by-id=%s | path=%s | class=%s | size=%s | model=%s | priority=%s\n" "$n" "$byid" "$path" "$class" "$size" "$model" "$priority" > /dev/tty
    n=$((n + 1))
  done
  printf "Select disk number [1] within 20s, or wait for auto-select: " > /dev/tty

  CHOICE=$(timeout 20 sh -c 'IFS= read -r ans < /dev/tty && printf "%s" "$ans"' 2>/dev/null || true)

  if [ -n "$CHOICE" ] && printf "%s" "$CHOICE" | grep -Eq '^[0-9]+$'; then
    PICKED=$(printf "%s\n" "$DISK_LINES" | sed -n "${CHOICE}p")
    if [ -n "$PICKED" ]; then
      SELECTED_LINE="$PICKED"
      AUTO_SELECTED=0
      USER_SELECTED=1
      SELECTION_SOURCE="interactive-menu"
    fi
  fi
fi

DISK=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $3 }')
DISK_REAL=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $4 }')
DISK_CLASS=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $5 }')
DISK_SIZE=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $6 }')
DISK_MODEL=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $7 }')
DISK_OCCUPIED=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $8 }')
DISK_ROOT_BACKING=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $9 }')
DISK_OCCUPANCY_REASONS=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $10 }')
DISK_MOUNT_SUMMARY=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $11 }')
DISK_HOLDER_SUMMARY=$(printf "%s\n" "$SELECTED_LINE" | awk -F'|' '{ print $12 }')
DESTRUCTIVE_CONFIRMATION="not-needed"

if [ "$DISK_OCCUPIED" = "1" ]; then
  if [ "$INTERACTIVE_TTY" -eq 1 ]; then
    echo "WARNING: selected disk appears to be in use and all data on it will be permanently destroyed by disko/NixOS install." > /dev/tty
    echo "  diskDevice = $DISK" > /dev/tty
    if [ -n "$DISK_OCCUPANCY_REASONS" ]; then
      echo "  occupiedBecause = $DISK_OCCUPANCY_REASONS" > /dev/tty
    fi
    if [ -n "$DISK_MOUNT_SUMMARY" ]; then
      echo "  mountSummary = $DISK_MOUNT_SUMMARY" > /dev/tty
    fi
    if [ -n "$DISK_HOLDER_SUMMARY" ]; then
      echo "  holderSummary = $DISK_HOLDER_SUMMARY" > /dev/tty
    fi
    printf "Type 'NO' within 20s to abort. Default action is WIPE and continue: " > /dev/tty

    WIPE_REPLY=$(timeout 20 sh -c 'IFS= read -r ans < /dev/tty && printf "%s" "$ans"' 2>/dev/null || true)
    WIPE_REPLY_LC=$(printf "%s" "$WIPE_REPLY" | tr '[:upper:]' '[:lower:]')

    case "$WIPE_REPLY_LC" in
      no|n|abort|cancel)
        echo "Aborted because selected disk is occupied and user declined destructive wipe." >&2
        exit 3
        ;;
      yes|y|wipe)
        DESTRUCTIVE_CONFIRMATION="interactive-explicit-wipe"
        ;;
      "")
        DESTRUCTIVE_CONFIRMATION="interactive-timeout-default-wipe"
        ;;
      *)
        DESTRUCTIVE_CONFIRMATION="interactive-default-wipe"
        ;;
    esac
  else
    DESTRUCTIVE_CONFIRMATION="noninteractive-default-wipe"
  fi
fi

mkdir -p "$(dirname "$OUT")"
{
  echo "{"
  echo "  diskDevice = \"$DISK\";"
  if [ -n "$CAMERA" ]; then
    echo "  cameraDevicePath = \"$CAMERA\";"
  else
    echo "  # cameraDevicePath intentionally omitted: no stable webcam symlink detected"
  fi
  echo "}"
} > "$OUT"

echo "Wrote $OUT"
if [ "$AUTO_SELECTED" -eq 1 ] && [ "$DISK_COUNT" -gt 1 ] && [ -z "$DISK_OVERRIDE" ]; then
  echo "  diskDevice = $DISK  (auto-selected first candidate: fastest class, then earliest device order)"
else
  echo "  diskDevice = $DISK"
fi
echo "  AUTOSELECTED=$AUTO_SELECTED"
echo "  USERSELECTED=$USER_SELECTED"
echo "  interactiveTTY=$INTERACTIVE_TTY"
echo "  selectionSource = $SELECTION_SOURCE"
echo "  originalCandidateCount = $ORIGINAL_DISK_COUNT"
echo "  filteredCandidateCount = $DISK_COUNT"
echo "  occupancyFilterApplied = $OCCUPANCY_FILTER_APPLIED"
if [ -n "$INSTALL_DISK_FILTER" ]; then
  echo "  diskFilter = $INSTALL_DISK_FILTER"
fi
if [ -n "$INSTALL_DISK_INDEX" ]; then
  echo "  diskIndex = $INSTALL_DISK_INDEX"
fi
echo "  diskRealPath = $DISK_REAL"
echo "  diskClass = $DISK_CLASS"
echo "  diskSize = $DISK_SIZE"
echo "  diskModel = $DISK_MODEL"
echo "  diskOccupied = $DISK_OCCUPIED"
echo "  rootBackingDisk = $DISK_ROOT_BACKING"
if [ -n "$DISK_OCCUPANCY_REASONS" ]; then
  echo "  occupiedBecause = $DISK_OCCUPANCY_REASONS"
fi
if [ -n "$DISK_MOUNT_SUMMARY" ]; then
  echo "  mountSummary = $DISK_MOUNT_SUMMARY"
fi
if [ -n "$DISK_HOLDER_SUMMARY" ]; then
  echo "  holderSummary = $DISK_HOLDER_SUMMARY"
fi
echo "  destructiveConfirmation = $DESTRUCTIVE_CONFIRMATION"
echo "  DATA_DESTRUCTION_WARNING=ALL_DATA_ON_SELECTED_DISK_WILL_BE_DESTROYED"
if [ -n "$CAMERA" ]; then
  echo "  cameraDevicePath = $CAMERA"
else
  echo "  cameraDevicePath = <not detected, using Nix default>"
fi
