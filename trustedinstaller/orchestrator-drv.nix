{ pkgs }:

pkgs.stdenvNoCC.mkDerivation {
  name = "install-honor-magicbook";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/libexec/local $out/libexec/remote

    install -m 755 local/fetch.sh   $out/libexec/local/fetch.sh
    install -m 755 local/install.sh $out/libexec/local/install.sh
    install -m 755 local/gen-hpasswd.sh $out/libexec/local/gen-hpasswd.sh

    install -m 755 remote/fetch.sh   $out/libexec/remote/fetch.sh

    install -m 755 install-system.sh $out/bin/install-honor-magicbook

    wrapProgram $out/bin/install-honor-magicbook \
      --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
        bash coreutils findutils gawk gnugrep gnused git mkpasswd nix util-linux
      ])}
  '';
}
