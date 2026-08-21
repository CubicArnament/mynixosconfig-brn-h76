#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
LANGUAGE=$(detect_language "$TARGET")
PACKAGES=$(language_packages "$LANGUAGE")
RUN_COMMAND=$(run_command "$LANGUAGE" "$TARGET")
BUILD_COMMAND=$(build_command "$LANGUAGE" "$TARGET")
refuse_existing "$TARGET/flake.nix"
refuse_existing "$TARGET/nix"
mkdir -p "$TARGET/nix/modules"

cat > "$TARGET/flake.nix" <<'EOF'
{
  description = "Big technology project flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      project = import ./nix { inherit inputs pkgs system; };
    in
    {
      inherit (project) apps devShells packages checks;
    };
}
EOF

cat > "$TARGET/nix/default.nix" <<EOF
{ inputs, pkgs, system }:

let
  projectModule = import ./modules/project.nix { inherit inputs pkgs system; };
in
{
  packages.\${system}.default = projectModule.package;
  apps.\${system} = {
    default = projectModule.runApp;
    run = projectModule.runApp;
    build = projectModule.buildApp;
  };
  devShells.\${system}.default = pkgs.mkShell {
    packages = [ ${PACKAGES} ];
  };
  checks.\${system}.default = projectModule.package;
}
EOF

cat > "$TARGET/nix/modules/project.nix" <<EOF
{ pkgs, ... }:

let
  package = pkgs.runCommand "project-placeholder" { } ''
    mkdir -p \$out
    echo "Replace nix/modules/project.nix with the real project build" > \$out/README
  '';
  runProgram = pkgs.writeShellScript "project-run" ''
    ${RUN_COMMAND}
  '';
  buildProgram = pkgs.writeShellScript "project-build" ''
    ${BUILD_COMMAND}
  '';
in
{
  inherit package;
  runApp = {
    type = "app";
    program = "\${runProgram}";
  };
  buildApp = {
    type = "app";
    program = "\${buildProgram}";
  };
}
EOF

printf "Created modular project flake for detected language: %s\n" "$LANGUAGE"
