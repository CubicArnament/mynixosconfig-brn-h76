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
    mkdir -p $out/bin

    install -m 755 fetch.sh   $out/bin/fetch-remote
    install -m 755 install.sh $out/bin/install-remote

    wrapProgram $out/bin/install-remote \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        nix openssh
      ])}
  '';
}
