#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 0 ]]; then
  printf "Usage: nix-hlp set-password\n" >&2
  exit 2
fi

cat <<'EOF'
This sets the local password for the configured user. The installer-generated
password should be changed immediately after installation.
EOF
exec passwd
