#!/usr/bin/env bash
set -euo pipefail

refuse_existing() {
  local path="$1"
  if [[ -e "$path" ]]; then
    printf "Refusing to overwrite existing path: %s\n" "$path" >&2
    exit 2
  fi
}

project_name() {
  local name
  name=$(basename "$1")
  name=${name//[^A-Za-z0-9_-]/-}
  printf '%s\n' "${name:-app}" | tr '[:upper:]' '[:lower:]'
}

python_module_name() {
  local name
  name=$(project_name "$1")
  name=${name//-/_}
  printf '%s\n' "${name,,}"
}

detect_language() {
  local root="$1" override="${NIX_HLP_LANGUAGE:-}"
  case "$override" in
    "") ;;
    rust|python|node|go|java|generic) printf '%s\n' "$override"; return ;;
    *) printf "Unsupported language: %s\n" "$override" >&2; exit 2 ;;
  esac

  if [[ -f "$root/Cargo.toml" ]]; then printf 'rust\n'
  elif [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" || -f "$root/Pipfile" ]]; then printf 'python\n'
  elif [[ -f "$root/package.json" || -f "$root/pnpm-lock.yaml" || -f "$root/yarn.lock" || -f "$root/bun.lock" || -f "$root/bun.lockb" ]]; then printf 'node\n'
  elif [[ -f "$root/go.mod" ]]; then printf 'go\n'
  elif [[ -f "$root/pom.xml" || -f "$root/build.gradle" || -f "$root/build.gradle.kts" || -f "$root/mvnw" || -f "$root/gradlew" ]]; then printf 'java\n'
  elif [[ -f "$root/Makefile" || -f "$root/CMakeLists.txt" || -f "$root/meson.build" ]]; then printf 'generic\n'
  else printf 'generic\n'
  fi
}

detect_package_manager() {
  local root="$1" language="$2"
  case "$language" in
    rust) printf 'cargo\n' ;;
    python)
      if [[ -f "$root/uv.lock" ]]; then printf 'uv\n'
      elif [[ -f "$root/poetry.lock" ]] || { [[ -f "$root/pyproject.toml" ]] && grep -q '\[tool\.poetry\]' "$root/pyproject.toml"; }; then printf 'poetry\n'
      elif [[ -f "$root/Pipfile" ]]; then printf 'pipenv\n'
      else printf 'pip\n'; fi
      ;;
    node)
      if [[ -f "$root/bun.lock" || -f "$root/bun.lockb" ]]; then printf 'bun\n'
      elif [[ -f "$root/pnpm-lock.yaml" ]]; then printf 'pnpm\n'
      elif [[ -f "$root/yarn.lock" ]]; then printf 'yarn\n'
      else printf 'npm\n'; fi
      ;;
    go) printf 'go\n' ;;
    java)
      if [[ -f "$root/mvnw" || -f "$root/pom.xml" ]]; then printf 'maven\n'
      else printf 'gradle\n'; fi
      ;;
    generic)
      if [[ -f "$root/CMakeLists.txt" ]]; then printf 'cmake\n'
      elif [[ -f "$root/meson.build" ]]; then printf 'meson\n'
      else printf 'make\n'; fi
      ;;
  esac
}

detect_framework() {
  local root="$1" language="$2"
  case "$language" in
    node)
      if [[ -f "$root/package.json" ]]; then
        if grep -q '"next"' "$root/package.json"; then printf 'next\n'
        elif grep -q '"vite"' "$root/package.json"; then printf 'vite\n'
        elif grep -q '"svelte"' "$root/package.json"; then printf 'svelte\n'
        elif grep -q '"@nestjs/' "$root/package.json"; then printf 'nestjs\n'
        else printf 'node\n'; fi
      else printf 'node\n'; fi
      ;;
    python)
      if grep -Eqs 'django|Django' "$root/pyproject.toml" "$root/requirements.txt" 2>/dev/null; then printf 'django\n'
      elif grep -Eqs 'fastapi' "$root/pyproject.toml" "$root/requirements.txt" 2>/dev/null; then printf 'fastapi\n'
      elif grep -Eqs 'flask|Flask' "$root/pyproject.toml" "$root/requirements.txt" 2>/dev/null; then printf 'flask\n'
      else printf 'python\n'; fi
      ;;
    rust)
      if grep -q 'axum' "$root/Cargo.toml" 2>/dev/null; then printf 'axum\n'
      elif grep -q 'actix-web' "$root/Cargo.toml" 2>/dev/null; then printf 'actix\n'
      else printf 'rust\n'; fi
      ;;
    java)
      if grep -Eqs 'spring-boot|org\.springframework\.boot' "$root/pom.xml" "$root/build.gradle" "$root/build.gradle.kts" 2>/dev/null; then printf 'spring\n'
      else printf 'java\n'; fi
      ;;
    *) printf '%s\n' "$language" ;;
  esac
}

detect_entrypoint() {
  local root="$1" language="$2" module
  case "$language" in
    rust) printf 'src/main.rs\n' ;;
    python)
      module=$(python_module_name "$root")
      if [[ -f "$root/main.py" ]]; then printf 'main.py\n'
      elif [[ -f "$root/src/$module/__main__.py" ]]; then printf 'src/%s/__main__.py\n' "$module"
      elif [[ -f "$root/app.py" ]]; then printf 'app.py\n'
      elif find "$root/src" -mindepth 2 -maxdepth 2 -type f -name __main__.py -print -quit 2>/dev/null | grep -q .; then
        find "$root/src" -mindepth 2 -maxdepth 2 -type f -name __main__.py -print -quit | sed "s|^$root/||"
      else printf 'src/%s/__main__.py\n' "$module"; fi
      ;;
    node)
      if [[ -f "$root/src/index.ts" ]]; then printf 'src/index.ts\n'
      elif [[ -f "$root/src/index.js" ]]; then printf 'src/index.js\n'
      elif [[ -f "$root/index.js" ]]; then printf 'index.js\n'
      else printf 'src/index.js\n'; fi
      ;;
    go) printf 'cmd/%s/main.go\n' "$(project_name "$root")" ;;
    java) printf 'src/main/java/App.java\n' ;;
    generic) printf 'src/main.c\n' ;;
  esac
}

detect_project() {
  PROJECT_ROOT="$1"
  PROJECT_NAME=$(project_name "$PROJECT_ROOT")
  PROJECT_LANGUAGE=$(detect_language "$PROJECT_ROOT")
  PROJECT_MANAGER=$(detect_package_manager "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  PROJECT_FRAMEWORK=$(detect_framework "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  PROJECT_ENTRYPOINT=$(detect_entrypoint "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  export PROJECT_ROOT PROJECT_NAME PROJECT_LANGUAGE PROJECT_MANAGER PROJECT_FRAMEWORK PROJECT_ENTRYPOINT
}

scaffold_project() {
  local module
  case "$PROJECT_LANGUAGE" in
    rust)
      if [[ ! -f "$PROJECT_ROOT/Cargo.toml" ]]; then
        mkdir -p "$PROJECT_ROOT/src"
        cat > "$PROJECT_ROOT/Cargo.toml" <<EOF
[package]
name = "$PROJECT_NAME"
version = "0.1.0"
edition = "2024"

[dependencies]
EOF
      fi
      if [[ ! -e "$PROJECT_ROOT/src/main.rs" ]]; then
        mkdir -p "$PROJECT_ROOT/src"
        printf 'fn main() {\n    println!("Hello from %s");\n}\n' "$PROJECT_NAME" > "$PROJECT_ROOT/src/main.rs"
      fi
      ;;
    python)
      module=$(python_module_name "$PROJECT_ROOT")
      if [[ ! -f "$PROJECT_ROOT/pyproject.toml" && ! -f "$PROJECT_ROOT/requirements.txt" && ! -f "$PROJECT_ROOT/Pipfile" ]]; then
        mkdir -p "$PROJECT_ROOT/src/$module" "$PROJECT_ROOT/tests"
        cat > "$PROJECT_ROOT/pyproject.toml" <<EOF
[build-system]
requires = ["setuptools>=69"]
build-backend = "setuptools.build_meta"

[project]
name = "$PROJECT_NAME"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
$PROJECT_NAME = "$module.__main__:main"
EOF
      fi
      if [[ ! -e "$PROJECT_ROOT/main.py" && ! -e "$PROJECT_ROOT/app.py" && ! -e "$PROJECT_ROOT/src/$module/__main__.py" ]]; then
        mkdir -p "$PROJECT_ROOT/src/$module"
        [[ -e "$PROJECT_ROOT/src/$module/__init__.py" ]] || : > "$PROJECT_ROOT/src/$module/__init__.py"
        printf 'def main():\n    print("Hello from %s")\n\n\nif __name__ == "__main__":\n    main()\n' "$PROJECT_NAME" > "$PROJECT_ROOT/src/$module/__main__.py"
      fi
      ;;
    node)
      if [[ ! -f "$PROJECT_ROOT/package.json" ]]; then
        mkdir -p "$PROJECT_ROOT/src" "$PROJECT_ROOT/test"
        cat > "$PROJECT_ROOT/package.json" <<EOF
{
  "name": "$PROJECT_NAME",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node src/index.js",
    "build": "node --check src/index.js",
    "test": "node --test"
  }
}
EOF
      fi
      if [[ ! -e "$PROJECT_ROOT/src/index.ts" && ! -e "$PROJECT_ROOT/src/index.js" && ! -e "$PROJECT_ROOT/index.js" ]]; then
        mkdir -p "$PROJECT_ROOT/src"
        printf 'console.log("Hello from %s");\n' "$PROJECT_NAME" > "$PROJECT_ROOT/src/index.js"
      fi
      ;;
    go)
      if [[ ! -f "$PROJECT_ROOT/go.mod" ]]; then
        mkdir -p "$PROJECT_ROOT/cmd/$PROJECT_NAME" "$PROJECT_ROOT/internal"
        printf 'module example.com/%s\n\ngo 1.24\n' "$PROJECT_NAME" > "$PROJECT_ROOT/go.mod"
      fi
      if [[ ! -e "$PROJECT_ROOT/cmd/$PROJECT_NAME/main.go" ]]; then
        mkdir -p "$PROJECT_ROOT/cmd/$PROJECT_NAME"
        printf 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello from %s")\n}\n' "$PROJECT_NAME" > "$PROJECT_ROOT/cmd/$PROJECT_NAME/main.go"
      fi
      ;;
    java)
      if [[ ! -f "$PROJECT_ROOT/pom.xml" && ! -f "$PROJECT_ROOT/build.gradle" && ! -f "$PROJECT_ROOT/build.gradle.kts" ]]; then
        mkdir -p "$PROJECT_ROOT/src/main/java" "$PROJECT_ROOT/src/test/java"
        cat > "$PROJECT_ROOT/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>$PROJECT_NAME</artifactId>
  <version>0.1.0</version>
  <properties><maven.compiler.release>21</maven.compiler.release></properties>
</project>
EOF
      fi
      if [[ ! -e "$PROJECT_ROOT/src/main/java/App.java" ]]; then
        mkdir -p "$PROJECT_ROOT/src/main/java"
        printf 'public class App {\n    public static void main(String[] args) {\n        System.out.println("Hello from %s");\n    }\n}\n' "$PROJECT_NAME" > "$PROJECT_ROOT/src/main/java/App.java"
      fi
      ;;
    generic)
      if [[ ! -f "$PROJECT_ROOT/Makefile" && ! -f "$PROJECT_ROOT/CMakeLists.txt" && ! -f "$PROJECT_ROOT/meson.build" ]]; then
        mkdir -p "$PROJECT_ROOT/src"
        cat > "$PROJECT_ROOT/Makefile" <<'EOF'
.PHONY: build run test
build:
	mkdir -p build
	$(CC) -Wall -Wextra -O2 -o build/app src/main.c
run: build
	./build/app
test: build
	./build/app
EOF
      fi
      if [[ ! -e "$PROJECT_ROOT/src/main.c" ]]; then
        mkdir -p "$PROJECT_ROOT/src"
        printf '#include <stdio.h>\nint main(void) { puts("Hello"); return 0; }\n' > "$PROJECT_ROOT/src/main.c"
      fi
      ;;
  esac
  PROJECT_MANAGER=$(detect_package_manager "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  PROJECT_FRAMEWORK=$(detect_framework "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  PROJECT_ENTRYPOINT=$(detect_entrypoint "$PROJECT_ROOT" "$PROJECT_LANGUAGE")
  export PROJECT_MANAGER PROJECT_FRAMEWORK PROJECT_ENTRYPOINT
}

language_packages() {
  case "$PROJECT_LANGUAGE:$PROJECT_MANAGER" in
    rust:*) printf 'pkgs.cargo pkgs.rustc pkgs.rustfmt pkgs.clippy' ;;
    python:uv) printf 'pkgs.python3 pkgs.uv pkgs.ruff' ;;
    python:poetry) printf 'pkgs.python3 pkgs.poetry pkgs.ruff' ;;
    python:pipenv) printf 'pkgs.python3 pkgs.pipenv pkgs.ruff' ;;
    python:*) printf 'pkgs.python3 pkgs.python3Packages.build pkgs.python3Packages.pip pkgs.python3Packages.virtualenv pkgs.ruff' ;;
    node:bun) printf 'pkgs.bun' ;;
    node:pnpm) printf 'pkgs.nodejs pkgs.pnpm' ;;
    node:yarn) printf 'pkgs.nodejs pkgs.yarn' ;;
    node:*) printf 'pkgs.nodejs' ;;
    go:*) printf 'pkgs.go pkgs.gopls pkgs.gotools' ;;
    java:maven) printf 'pkgs.jdk21 pkgs.maven' ;;
    java:gradle) printf 'pkgs.jdk21 pkgs.gradle' ;;
    generic:cmake) printf 'pkgs.clang pkgs.cmake pkgs.ninja' ;;
    generic:meson) printf 'pkgs.clang pkgs.meson pkgs.ninja pkgs.pkg-config' ;;
    generic:*) printf 'pkgs.clang pkgs.gnumake pkgs.pkg-config' ;;
  esac
}

run_command() {
  case "$PROJECT_LANGUAGE:$PROJECT_MANAGER" in
    rust:*) printf 'cargo run -- "$@"' ;;
    python:uv) printf 'uv run python %q "$@"' "$PROJECT_ENTRYPOINT" ;;
    python:poetry) printf 'poetry run python %q "$@"' "$PROJECT_ENTRYPOINT" ;;
    python:pipenv) printf 'pipenv run python %q "$@"' "$PROJECT_ENTRYPOINT" ;;
    python:*) printf 'python %q "$@"' "$PROJECT_ENTRYPOINT" ;;
    node:bun) printf 'bun run start -- "$@"' ;;
    node:pnpm)
      if grep -Eq '"start"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'pnpm start -- "$@"'
      else printf 'node %q "$@"' "$PROJECT_ENTRYPOINT"; fi
      ;;
    node:yarn)
      if grep -Eq '"start"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'yarn start "$@"'
      else printf 'node %q "$@"' "$PROJECT_ENTRYPOINT"; fi
      ;;
    node:*)
      if grep -Eq '"start"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'npm start -- "$@"'
      else printf 'node %q "$@"' "$PROJECT_ENTRYPOINT"; fi
      ;;
    go:*) printf 'go run ./cmd/%q -- "$@"' "$PROJECT_NAME" ;;
    java:maven) printf 'mvn exec:java -Dexec.mainClass=App -Dexec.args="$*"' ;;
    java:gradle)
      if [[ -x "$PROJECT_ROOT/gradlew" ]]; then printf './gradlew run --args="$*"'
      else printf 'gradle run --args="$*"'; fi
      ;;
    generic:*) printf 'make run ARGS="$*"' ;;
  esac
}

build_command() {
  case "$PROJECT_LANGUAGE:$PROJECT_MANAGER" in
    rust:*) printf 'cargo build --release "$@"' ;;
    python:uv) printf 'uv build "$@"' ;;
    python:poetry) printf 'poetry build "$@"' ;;
    python:pipenv) printf 'pipenv run python -m build "$@"' ;;
    python:*) printf 'python -m build "$@"' ;;
    node:bun)
      if grep -Eq '"build"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'bun run build -- "$@"'
      else printf 'bun --check %q' "$PROJECT_ENTRYPOINT"; fi
      ;;
    node:pnpm)
      if grep -Eq '"build"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'pnpm build -- "$@"'
      else printf 'node --check %q' "$PROJECT_ENTRYPOINT"; fi
      ;;
    node:yarn)
      if grep -Eq '"build"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'yarn build "$@"'
      else printf 'node --check %q' "$PROJECT_ENTRYPOINT"; fi
      ;;
    node:*)
      if grep -Eq '"build"[[:space:]]*:' "$PROJECT_ROOT/package.json" 2>/dev/null; then printf 'npm run build -- "$@"'
      else printf 'node --check %q' "$PROJECT_ENTRYPOINT"; fi
      ;;
    go:*) printf 'mkdir -p build; go build -o build/%q ./cmd/%q' "$PROJECT_NAME" "$PROJECT_NAME" ;;
    java:maven) printf 'mvn package "$@"' ;;
    java:gradle)
      if [[ -x "$PROJECT_ROOT/gradlew" ]]; then printf './gradlew build "$@"'
      else printf 'gradle build "$@"'; fi
      ;;
    generic:*) printf 'make build "$@"' ;;
  esac
}

shell_hook() {
  case "$PROJECT_LANGUAGE:$PROJECT_MANAGER" in
    python:*) printf 'export PYTHONPATH="$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"' ;;
    rust:*) printf 'export RUST_BACKTRACE=1' ;;
    go:*) printf 'export GOPATH="$PWD/.cache/go"' ;;
    node:*) printf 'export NODE_ENV=development' ;;
    java:*) printf 'export JAVA_HOME="${pkgs.jdk21}"' ;;
    generic:*) printf ':' ;;
  esac
}

write_app_flake() {
  local target="$1" app_name="$2" command="$3" packages="$4"
  refuse_existing "$target/flake.nix"
  cat > "$target/flake.nix" <<EOF
{
  description = "Generated ${PROJECT_LANGUAGE}/${PROJECT_FRAMEWORK} project ${app_name} app";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.\${system};
      ${app_name} = pkgs.writeShellApplication {
        name = "${PROJECT_NAME}-${app_name}";
        runtimeInputs = [ ${packages} ];
        text = ''
          ${command}
        '';
      };
    in
    {
      apps.\${system}.default = {
        type = "app";
        program = "\${${app_name}}/bin/${PROJECT_NAME}-${app_name}";
      };
    };
}
EOF
}

print_project_summary() {
  printf "Detected project: language=%s manager=%s framework=%s entrypoint=%s\n" \
    "$PROJECT_LANGUAGE" "$PROJECT_MANAGER" "$PROJECT_FRAMEWORK" "$PROJECT_ENTRYPOINT"
}
