#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
LANGUAGE=$(detect_language "$TARGET")
write_app_flake "$TARGET" build "$(build_command "$LANGUAGE" "$TARGET")" "$(language_packages "$LANGUAGE")"
printf "Created build app for detected language: %s\n" "$LANGUAGE"
