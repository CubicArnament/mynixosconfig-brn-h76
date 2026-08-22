#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
detect_project "$TARGET"
scaffold_project
PACKAGES=$(language_packages)
SHELL_HOOK=$(shell_hook)
refuse_existing "$TARGET/shell.nix"

cat > "$TARGET/shell.nix" <<EOF
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [ ${PACKAGES} ];
  shellHook = ''
    ${SHELL_HOOK}
  '';
}
EOF

print_project_summary
printf "Created %s\n" "$TARGET/shell.nix"
