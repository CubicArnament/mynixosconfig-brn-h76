# trustedinstaller/orchestrator-drv.nix
#
# Деривация для install-honor-magicbook — оркестратор (bash).
# Раскладывает скрипты в bin/ и libexec/local/ + libexec/remote/.
# Оркестратор находит libexec/ через $(dirname $0)/../libexec.

{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "install-honor-magicbook";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/libexec/local $out/libexec/remote

    # local/ — bash
    install -m 755 local/fetch.sh   $out/libexec/local/fetch.sh
    install -m 755 local/install.sh $out/libexec/local/install.sh

    # remote/ — POSIX sh
    install -m 755 remote/fetch.sh   $out/libexec/remote/fetch.sh
    install -m 755 remote/install.sh $out/libexec/remote/install.sh

    # оркестратор — в bin/, при запуске находит libexec/ через BIN_DIR/../libexec
    install -m 755 install-system.sh $out/bin/install-honor-magicbook

    wrapProgram $out/bin/install-honor-magicbook \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash coreutils findutils gawk gnugrep gnused git nix openssh util-linux
      ])}
  '';
}
