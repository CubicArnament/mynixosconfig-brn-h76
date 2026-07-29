#!/usr/bin/env bash
# trustedinstaller/local/fetch.sh
#
# bash — детект дисков и камеры локально, записывает local-device-paths.nix.
# Запускать с live ISO на целевом железе.
#
# Использование:
#   fetch.sh <output-file> [disk-override] [camera-override]
#
# Переменные окружения:
#   INSTALL_DISK_FILTER  — фильтр (подстрока модели/класса, или "system"/"root")
#   INSTALL_DISK_INDEX   — номер кандидата (1-based)
set -euo pipefail

OUT="${1:-hosts/honor-magicbook-x16-pro/local-device-paths.nix}"
DISK_OVERRIDE="${2:-}"
CAMERA_OVERRIDE="${3:-}"
INSTALL_DISK_FILTER="${INSTALL_DISK_FILTER:-}"
INSTALL_DISK_INDEX="${INSTALL_DISK_INDEX:-}"

# В store скрипты лежат рядом в одной папке (bin/ или libexec/)
# В репо — в local/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В store скрипт в libexec/local/, remote/fetch.sh — в libexec/remote/
# В репо (trustedinstaller/local/) — ../remote/fetch.sh
if [[ -f "$SCRIPT_DIR/../remote/fetch.sh" ]]; then
  REMOTE_FETCH="$SCRIPT_DIR/../remote/fetch.sh"
elif [[ -f "$SCRIPT_DIR/fetch-remote.sh" ]]; then
  # fallback: рядом в одной папке (store без подпапок)
  REMOTE_FETCH="$SCRIPT_DIR/fetch-remote.sh"
else
  printf "fetch-remote.sh not found\n" >&2; exit 1
fi

RESULT=$(sh "$REMOTE_FETCH" "$DISK_OVERRIDE" "$CAMERA_OVERRIDE")

mapfile -t DISK_LINES_ARR < <(printf "%s\n" "$RESULT" | grep '^DISK|' || true)
CAMERA=$(printf "%s\n" "$RESULT" | awk -F'|' '/^CAMERA\|/ { sub(/^CAMERA\|/, "", $0); print; exit }')

if [[ ${#DISK_LINES_ARR[@]} -eq 0 ]]; then
  printf "No usable /dev/disk/by-id candidates detected locally.\n" >&2
  exit 2
fi

ORIGINAL_DISK_COUNT=${#DISK_LINES_ARR[@]}
OCCUPANCY_FILTER_APPLIED=0
INTERACTIVE_TTY=0

[[ -t 0 && -t 1 && -r /dev/tty ]] && INTERACTIVE_TTY=1

if [[ -n "$INSTALL_DISK_FILTER" && -z "$DISK_OVERRIDE" ]]; then
  FILTER_KIND="${INSTALL_DISK_FILTER,,}"
  case "$FILTER_KIND" in
    system|root)
      FILTERED=$(printf "%s\n" "${DISK_LINES_ARR[@]}" | awk -F'|' '$9 == "1"')
      ;;
    *)
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

if [[ -z "$DISK_OVERRIDE" && "$INTERACTIVE_TTY" -eq 0 ]]; then
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
    IFS='|' read -r _ priority byid path class size model _ _ _ _ _ <<< "${DISK_LINES_ARR[$i]}"
    printf "  [%s] %s  %s  %s  %s  %s\n" \
      "$(( i + 1 ))" "$byid" "$path" "$class" "$size" "$model" > /dev/tty
  done
  printf "Select disk [1] within 20s, or wait for auto-select: " > /dev/tty
  CHOICE=""; IFS= read -r -t 20 CHOICE < /dev/tty || true
  if [[ "$CHOICE" =~ ^[0-9]+$ ]]; then
    IDX=$(( CHOICE - 1 ))
    if (( IDX >= 0 && IDX < DISK_COUNT )); then
      SELECTED_LINE="${DISK_LINES_ARR[$IDX]}"
      AUTO_SELECTED=0; USER_SELECTED=1; SELECTION_SOURCE="interactive-menu"
    fi
  fi
fi

IFS='|' read -r _ _priority DISK DISK_REAL DISK_CLASS DISK_SIZE DISK_MODEL \
  DISK_OCCUPIED DISK_ROOT_BACKING DISK_OCCUPANCY_REASONS \
  DISK_MOUNT_SUMMARY DISK_HOLDER_SUMMARY <<< "$SELECTED_LINE"

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
