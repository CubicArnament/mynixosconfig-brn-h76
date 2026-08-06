{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "honor-magicbook-remote-install";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/libexec/local $out/libexec/remote

    install -m 755 ${../fetch-system.sh} $out/bin/fetch-target-device-paths
    install -m 755 ${../local/fetch.sh}  $out/libexec/local/fetch.sh
    install -m 755 fetch.sh             $out/libexec/remote/fetch.sh

    wrapProgram $out/bin/fetch-target-device-paths \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash coreutils findutils gawk gnugrep openssh
      ])}
  '';
}
