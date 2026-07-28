# trustedinstaller/local/drv.nix
#
# Деривация для отдельного использования локального фетча и установки (bash).

{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "honor-magicbook-local";
  src = ../.;  # весь trustedinstaller/ — нужен remote/fetch.sh

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    # remote/fetch.sh рядом с fetch.sh — local/fetch.sh ищет его через fallback
    install -m 755 remote/fetch.sh $out/bin/fetch-remote.sh
    install -m 755 local/fetch.sh  $out/bin/fetch-local
    install -m 755 local/install.sh $out/bin/install-local

    wrapProgram $out/bin/fetch-local \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash coreutils findutils gawk gnugrep gnused util-linux
      ])}

    wrapProgram $out/bin/install-local \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash nix
      ])}
  '';
}
