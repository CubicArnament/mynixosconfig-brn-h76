#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-hosts/honor-magicbook-x16-pro/local-device-paths.nix}"
DISK_OVERRIDE="${2:-}"
CAMERA_OVERRIDE="${3:-}"
INSTALL_DISK_FILTER="${INSTALL_DISK_FILTER:-}"
INSTALL_DISK_INDEX="${INSTALL_DISK_INDEX:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../remote/fetch.sh" ]]; then
  REMOTE_FETCH="$SCRIPT_DIR/../remote/fetch.sh"
else
  printf "remote/fetch.sh not found\n" >&2; exit 1
fi

if [[ -n "${FETCH_RESULT:-}" ]]; then
  RESULT=$FETCH_RESULT
else
  RESULT=$(sh "$REMOTE_FETCH")
fi

mapfile -t DISK_LINES_ARR < <(printf "%s\n" "$RESULT" | grep '^DISK|' || true)
CAMERA=$(printf "%s\n" "$RESULT" | awk -F'|' '/^CAMERA\|/ { sub(/^CAMERA\|/, "", $0); print; exit }')

if [[ -n "$DISK_OVERRIDE" ]]; then
  if [[ ! "$DISK_OVERRIDE" =~ ^/dev/disk/by-id/[A-Za-z0-9._+:-]+$ ]]; then
    printf "Refusing unsafe disk override: %s\n" "$DISK_OVERRIDE" >&2
    exit 2
  fi
  mapfile -t DISK_LINES_ARR < <(
    printf "%s\n" "${DISK_LINES_ARR[@]}" | awk -F'|' -v disk="$DISK_OVERRIDE" '$3 == disk'
  )
  if [[ ${#DISK_LINES_ARR[@]} -eq 0 ]]; then
    printf "Disk override is not a detected whole-disk by-id path: %s\n" "$DISK_OVERRIDE" >&2
    exit 2
  fi
fi

if [[ -n "$CAMERA_OVERRIDE" ]]; then
  if [[ ! "$CAMERA_OVERRIDE" =~ ^/dev/v4l/by-(id|path)/[A-Za-z0-9._+:-]+$ ]]; then
    printf "Refusing unsafe camera override: %s\n" "$CAMERA_OVERRIDE" >&2
    exit 2
  fi
  CAMERA=$CAMERA_OVERRIDE
fi

if [[ ${#DISK_LINES_ARR[@]} -eq 0 ]]; then
  printf "No usable /dev/disk/by-id candidates detected locally.\n" >&2
  exit 2
fi

ORIGINAL_DISK_COUNT=${#DISK_LINES_ARR[@]}
OCCUPANCY_FILTER_APPLIED=0
INTERACTIVE_TTY=0

if [[ -r /dev/tty && -w /dev/tty ]] && (: < /dev/tty) 2>/dev/null; then
  INTERACTIVE_TTY=1
fi

if [[ -n "$INSTALL_DISK_FILTER" && -z "$DISK_OVERRIDE" ]]; then
  FILTER_KIND="${INSTALL_DISK_FILTER,,}"
  case "$FILTER_KIND" in
    system|root)
      FILTERED=$(printf "%s\n" "${DISK_LINES_ARR[@]}" | awk -F'|' '$9 == "1"')
      ;;
    *)
      if ! [[ "$INSTALL_DISK_FILTER" =~ ^[A-Za-z0-9._-]+$ ]]; then
        printf "INSTALL_DISK_FILTER contains unsafe characters\n" >&2
        exit 2
      fi
      FILTERED=$(printf "%s\n" "${DISK_LINES_ARR[@]}" | awk -F'|' -v n="$INSTALL_DISK_FILTER" '
        BEGIN { nl = tolower(n) }
        { if (index(tolower($0), nl) > 0) print }
      ')
      ;;
  esac
  if [[ -z "$FILTERED" ]]; then
    printf "INSTALL_DISK_FILTER=%s matched nothing.\n" "$INSTALL_DISK_FILTER" >&2
    exit 2
  fi
  mapfile -t DISK_LINES_ARR <<< "$FILTERED"
fi

if [[ -z "$DISK_OVERRIDE" ]]; then
  FILTER_KIND="${INSTALL_DISK_FILTER,,}"
  if [[ "$FILTER_KIND" != "system" && "$FILTER_KIND" != "root" ]]; then
    UNOCCUPIED=$(printf "%s\n" "${DISK_LINES_ARR[@]}" | awk -F'|' '$8 == "0"')
    if [[ -n "$UNOCCUPIED" ]]; then
      mapfile -t DISK_LINES_ARR <<< "$UNOCCUPIED"
      OCCUPANCY_FILTER_APPLIED=1
    fi
  fi
fi

DISK_COUNT=${#DISK_LINES_ARR[@]}

if (( DISK_COUNT > 1 && INTERACTIVE_TTY == 0 )) \
  && [[ -z "$DISK_OVERRIDE" && -z "$INSTALL_DISK_INDEX" ]]; then
  printf "Multiple filtered disks require INSTALL_DISK_INDEX in non-interactive mode.\n" >&2
  exit 2
fi

SELECTED_LINE="${DISK_LINES_ARR[0]}"
AUTO_SELECTED=1; USER_SELECTED=0
SELECTION_SOURCE="single-candidate"

if (( DISK_COUNT > 1 )); then
  (( INTERACTIVE_TTY )) \
    && SELECTION_SOURCE="auto-timeout-or-default" \
    || SELECTION_SOURCE="auto-noninteractive"
fi

if [[ -n "$DISK_OVERRIDE" ]]; then
  AUTO_SELECTED=0; USER_SELECTED=1; SELECTION_SOURCE="explicit-override"

elif [[ -n "$INSTALL_DISK_INDEX" ]]; then
  if ! [[ "$INSTALL_DISK_INDEX" =~ ^[1-9][0-9]*$ ]]; then
    printf "INSTALL_DISK_INDEX must be a positive integer.\n" >&2; exit 2
  fi
  IDX=$(( INSTALL_DISK_INDEX - 1 ))
  if (( IDX >= DISK_COUNT )); then
    printf "INSTALL_DISK_INDEX=%s out of range (%s candidates).\n" \
      "$INSTALL_DISK_INDEX" "$DISK_COUNT" >&2; exit 2
  fi
  SELECTED_LINE="${DISK_LINES_ARR[$IDX]}"
  AUTO_SELECTED=0; USER_SELECTED=1; SELECTION_SOURCE="env-disk-index"

elif (( DISK_COUNT > 1 && INTERACTIVE_TTY )); then
  printf "Multiple install disk candidates found:\n" > /dev/tty
  for (( i = 0; i < DISK_COUNT; i++ )); do
    IFS='|' read -r _ _ byid path class size model occupied _ reasons _ _ \
      <<< "${DISK_LINES_ARR[$i]}"
    status="free"
    if [[ "$occupied" == "1" ]]; then
      status="OCCUPIED:${reasons:-unknown}"
    fi
    printf "  [%s] %s  %s  %s  %s bytes  %s  [%s]\n" \
      "$(( i + 1 ))" "$byid" "$path" "$class" "$size" "$model" "$status" > /dev/tty
  done
  printf "Select disk (required): " > /dev/tty
  CHOICE=""; IFS= read -r CHOICE < /dev/tty || true
  if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
    IDX=$(( CHOICE - 1 ))
    if (( IDX >= 0 && IDX < DISK_COUNT )); then
      SELECTED_LINE="${DISK_LINES_ARR[$IDX]}"
      AUTO_SELECTED=0; USER_SELECTED=1; SELECTION_SOURCE="interactive-menu"
    fi
  fi
fi

if (( DISK_COUNT > 1 && AUTO_SELECTED )); then
  printf "Multiple disks require an explicit selection via the menu or INSTALL_DISK_INDEX.\n" >&2
  exit 2
fi

IFS='|' read -r _ _priority DISK DISK_REAL DISK_CLASS DISK_SIZE DISK_MODEL \
  DISK_OCCUPIED DISK_ROOT_BACKING DISK_OCCUPANCY_REASONS \
  DISK_MOUNT_SUMMARY DISK_HOLDER_SUMMARY <<< "$SELECTED_LINE"

if [[ ! "$DISK" =~ ^/dev/disk/by-id/[A-Za-z0-9._+:-]+$ ]]; then
  printf "Refusing unsafe disk path: %s\n" "$DISK" >&2
  exit 2
fi

if [[ -n "$CAMERA" && ! "$CAMERA" =~ ^/dev/v4l/by-(id|path)/[A-Za-z0-9._+:-]+$ ]]; then
  printf "Refusing unsafe camera path: %s\n" "$CAMERA" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT")"
{
  printf "{\n"
  printf "  diskDevice = \"%s\";\n" "$DISK"
  if [[ -n "$CAMERA" ]]; then
    printf "  cameraDevicePath = \"%s\";\n" "$CAMERA"
  else
    printf "  cameraDevicePath = \"\";\n"
  fi
  printf "}\n"
} > "$OUT"

printf "Wrote %s\n"                        "$OUT"
printf "  diskDevice         = %s\n"       "$DISK"
printf "  selectionSource    = %s\n"       "$SELECTION_SOURCE"
printf "  autoSelected       = %s\n"       "$AUTO_SELECTED"
printf "  userSelected       = %s\n"       "$USER_SELECTED"
printf "  interactiveTTY     = %s\n"       "$INTERACTIVE_TTY"
printf "  originalCandidates = %s\n"       "$ORIGINAL_DISK_COUNT"
printf "  filteredCandidates = %s\n"       "$DISK_COUNT"
printf "  occupancyFiltered  = %s\n"       "$OCCUPANCY_FILTER_APPLIED"
printf "  diskRealPath       = %s\n"       "$DISK_REAL"
printf "  diskClass          = %s\n"       "$DISK_CLASS"
printf "  diskSize           = %s\n"       "$DISK_SIZE"
printf "  diskModel          = %s\n"       "$DISK_MODEL"
printf "  diskOccupied       = %s\n"       "$DISK_OCCUPIED"
printf "  rootBacking        = %s\n"       "$DISK_ROOT_BACKING"
[[ -n "$DISK_OCCUPANCY_REASONS" ]] && printf "  occupiedBecause    = %s\n" "$DISK_OCCUPANCY_REASONS"
[[ -n "$DISK_MOUNT_SUMMARY"     ]] && printf "  mountSummary       = %s\n" "$DISK_MOUNT_SUMMARY"
[[ -n "$DISK_HOLDER_SUMMARY"    ]] && printf "  holderSummary      = %s\n" "$DISK_HOLDER_SUMMARY"
[[ -n "$INSTALL_DISK_FILTER"    ]] && printf "  diskFilter         = %s\n" "$INSTALL_DISK_FILTER"
[[ -n "$INSTALL_DISK_INDEX"     ]] && printf "  diskIndex          = %s\n" "$INSTALL_DISK_INDEX"
if [[ -n "$CAMERA" ]]; then
  printf "  cameraDevicePath   = %s\n" "$CAMERA"
else
  printf "  cameraDevicePath   = <not detected>\n"
fi
