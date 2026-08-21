#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
LANGUAGE=$(detect_language "$TARGET")
write_app_flake "$TARGET" run "$(run_command "$LANGUAGE" "$TARGET")" "$(language_packages "$LANGUAGE")"
printf "Created run app for detected language: %s\n" "$LANGUAGE"
