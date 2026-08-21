#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
LANGUAGE=$(detect_language "$TARGET")
PACKAGES=$(language_packages "$LANGUAGE")
refuse_existing "$TARGET/flake.nix"

cat > "$TARGET/flake.nix" <<EOF
{
  description = "Development flake for a ${LANGUAGE} project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
    in
    {
      devShells.\${system}.default = pkgs.mkShell {
        packages = [ ${PACKAGES} ];
      };
    };
}
EOF

printf "Created %s for detected language: %s\n" "$TARGET/flake.nix" "$LANGUAGE"
