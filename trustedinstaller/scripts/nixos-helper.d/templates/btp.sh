#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="$1"
detect_project "$TARGET"
scaffold_project
PACKAGES=$(language_packages)
RUN_COMMAND=$(run_command)
BUILD_COMMAND=$(build_command)
SHELL_HOOK=$(shell_hook)
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
    shellHook = ''
      ${SHELL_HOOK}
    '';
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

print_project_summary
printf "Created modular project flake with run and build apps.\n"
