#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
detect_project "$TARGET"
scaffold_project
PACKAGES=$(language_packages)
SHELL_HOOK=$(shell_hook)
refuse_existing "$TARGET/flake.nix"

cat > "$TARGET/flake.nix" <<EOF
{
  description = "Development flake for ${PROJECT_NAME} (${PROJECT_LANGUAGE}/${PROJECT_FRAMEWORK})";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
    in
    {
      devShells.\${system}.default = pkgs.mkShell {
        packages = [ ${PACKAGES} ];
        shellHook = ''
          ${SHELL_HOOK}
        '';
      };
    };
}
EOF

print_project_summary
printf "Created %s\n" "$TARGET/flake.nix"
