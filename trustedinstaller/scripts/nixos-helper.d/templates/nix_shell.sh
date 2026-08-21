#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
LANGUAGE=$(detect_language "$TARGET")
PACKAGES=$(language_packages "$LANGUAGE")
refuse_existing "$TARGET/shell.nix"

cat > "$TARGET/shell.nix" <<EOF
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [ ${PACKAGES} ];
}
EOF

printf "Created %s for detected language: %s\n" "$TARGET/shell.nix" "$LANGUAGE"
