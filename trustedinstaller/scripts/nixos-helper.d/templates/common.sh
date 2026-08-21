#!/usr/bin/env bash
set -euo pipefail

refuse_existing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf "Refusing to overwrite existing path: %s\n" "$path" >&2
    exit 2
  fi
}

detect_language() {
  local root="$1"
  if [[ -f "$root/Cargo.toml" ]]; then printf 'rust\n'
  elif [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" ]]; then printf 'python\n'
  elif [[ -f "$root/package.json" ]]; then printf 'node\n'
  elif [[ -f "$root/go.mod" ]]; then printf 'go\n'
  elif [[ -f "$root/pom.xml" || -f "$root/build.gradle" || -f "$root/build.gradle.kts" ]]; then printf 'java\n'
  else printf 'generic\n'
  fi
}

language_packages() {
  case "$1" in
    rust) printf 'pkgs.cargo pkgs.rustc pkgs.rustfmt' ;;
    python) printf 'pkgs.python3 pkgs.python3Packages.build pkgs.python3Packages.pip pkgs.python3Packages.virtualenv' ;;
    node) printf 'pkgs.nodejs' ;;
    go) printf 'pkgs.go pkgs.gopls' ;;
    java) printf 'pkgs.jdk pkgs.maven pkgs.gradle' ;;
    generic) printf 'pkgs.git pkgs.gnumake' ;;
  esac
}

run_command() {
  case "$1" in
    rust) printf 'cargo run -- "$@"' ;;
    python)
      if [[ -f "$2/main.py" ]]; then printf 'python main.py "$@"'
      else printf 'python -m main "$@"'; fi
      ;;
    node)
      if [[ -f "$2/package.json" ]] && grep -Eq '"start"[[:space:]]*:' "$2/package.json"; then printf 'npm start -- "$@"'
      else printf 'node . "$@"'; fi
      ;;
    go) printf 'go run . -- "$@"' ;;
    java)
      if [[ -f "$2/pom.xml" ]]; then printf 'mvn exec:java -Dexec.args="$*"'
      else printf 'gradle run --args="$*"'; fi
      ;;
    generic) printf 'make run ARGS="$*"' ;;
  esac
}

build_command() {
  case "$1" in
    rust) printf 'cargo build --release "$@"' ;;
    python) printf 'python -m build "$@"' ;;
    node) printf 'npm run build -- "$@"' ;;
    go) printf 'go build "$@" ./...' ;;
    java)
      if [[ -f "$2/pom.xml" ]]; then printf 'mvn package "$@"'
      else printf 'gradle build "$@"'; fi
      ;;
    generic) printf 'make "$@"' ;;
  esac
}

write_app_flake() {
  local target="$1" app_name="$2" command="$3" packages="$4"
  refuse_existing "$target/flake.nix"
  cat > "$target/flake.nix" <<EOF
{
  description = "Generated project ${app_name} app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
      ${app_name} = pkgs.writeShellApplication {
        name = "project-${app_name}";
        runtimeInputs = [ ${packages} ];
        text = ''
          ${command}
        '';
      };
    in
    {
      apps.\${system}.default = {
        type = "app";
        program = "\${${app_name}}/bin/project-${app_name}";
      };
    };
}
EOF
}
