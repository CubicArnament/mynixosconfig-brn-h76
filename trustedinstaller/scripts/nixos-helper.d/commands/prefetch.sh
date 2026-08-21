#!/usr/bin/env bash
set -euo pipefail
exec nix-prefetch-maintaining "$@"
