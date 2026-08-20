{ stdenvNoCC, makeWrapper, mkpasswd }:

stdenvNoCC.mkDerivation {
  pname = "gen-hpasswd";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/libexec/local

    install -m 755 local/gen-hpasswd.sh $out/libexec/local/gen-hpasswd.sh
    install -m 755 gen-hpasswd.sh $out/bin/gen-hpasswd

    wrapProgram $out/bin/gen-hpasswd \
      --prefix PATH : ${mkpasswd}/bin

    wrapProgram $out/libexec/local/gen-hpasswd.sh \
      --prefix PATH : ${mkpasswd}/bin

    runHook postInstall
  '';

  meta = {
    description = "Interactive hashed password generator for NixOS installation";
    mainProgram = "gen-hpasswd";
  };
}
