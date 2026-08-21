{ coreutils, lib, stdenvNoCC, makeWrapper, mkpasswd }:

stdenvNoCC.mkDerivation {
  pname = "gen-hpasswd";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 755 local/gen-hpasswd.sh $out/bin/gen-hpasswd

    wrapProgram $out/bin/gen-hpasswd \
      --prefix PATH : ${lib.makeBinPath [ coreutils mkpasswd ]}

    runHook postInstall
  '';

  meta = {
    description = "Interactive hashed password generator for NixOS installation";
    mainProgram = "gen-hpasswd";
  };
}
