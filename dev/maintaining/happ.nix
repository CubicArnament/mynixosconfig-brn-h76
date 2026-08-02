{ autoPatchelfHook, dpkg, fetchurl, fontconfig, freetype, libGL, libxcb, stdenv }:

stdenv.mkDerivation rec {
  pname = "happ";
  version = "3.3.6";

  src = fetchurl {
    url = "https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.deb";
    hash = "sha256-p9rFEnc4e/4QSbGtQPQPLnSvIzpeqwILW+GmIu/8RqQ=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook ];
  buildInputs = [ libGL libxcb fontconfig freetype ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    dpkg -x $src .
    mkdir -p $out/bin
    cp -r opt/ $out/
    ln -s $out/opt/happ/bin/Happ $out/bin/happ
    runHook postInstall
  '';

  meta = {
    description = "Happ Proxy Utility Client";
    homepage = "https://github.com/Happ-proxy/happ-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
