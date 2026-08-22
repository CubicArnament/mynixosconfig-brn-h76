#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
detect_project "$TARGET"
scaffold_project
write_app_flake "$TARGET" build "$(build_command)" "$(language_packages)"
print_project_summary
printf "Created build app: nix run .\n"
