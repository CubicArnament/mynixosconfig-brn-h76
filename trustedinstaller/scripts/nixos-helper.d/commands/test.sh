#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 -- resolved relative to this installed script
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
run_system_rebuild test "$@"
