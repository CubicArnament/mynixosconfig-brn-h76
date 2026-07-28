# trustedinstaller/remote/drv.nix
#
# Деривация для удалённой установки (POSIX sh).
# fetch.sh — передаётся на целевую машину через SSH pipe.
# install.sh — запускается локально, но написан на POSIX sh.

{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "honor-magicbook-remote-install";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/libexec/local $out/libexec/remote

    install -m 755 ${../fetch-system.sh} $out/bin/fetch-target-device-paths
    install -m 755 ${../local/fetch.sh}  $out/libexec/local/fetch.sh
    install -m 755 ${../local/install.sh} $out/libexec/local/install.sh
    install -m 755 fetch.sh             $out/libexec/remote/fetch.sh
    install -m 755 install.sh           $out/libexec/remote/install.sh
    install -m 755 fetch.sh             $out/bin/fetch-remote
    install -m 755 install.sh           $out/bin/install-remote

    wrapProgram $out/bin/fetch-target-device-paths \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash coreutils findutils gawk gnugrep gnused util-linux nix openssh
      ])}

    wrapProgram $out/bin/install-remote \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        nix openssh
      ])}
  '';
}
