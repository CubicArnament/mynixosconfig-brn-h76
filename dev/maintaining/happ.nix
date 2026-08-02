{ autoPatchelfHook, dpkg, e2fsprogs, fetchurl, fontconfig, freetype, libGL, libgpg-error, libxcb, qt6, stdenv }:

stdenv.mkDerivation rec {
  pname = "happ";
  version = "3.3.6";

  src = fetchurl {
    url = "https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.deb";
    hash = "sha256-p9rFEnc4e/4QSbGtQPQPLnSvIzpeqwILW+GmIu/8RqQ=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook ];
  # The bundled Qt/QML plugins link against the GCC C++ runtime.
  buildInputs = [
    libGL
    libxcb
    fontconfig
    freetype
    stdenv.cc.cc.lib
    e2fsprogs
    libgpg-error
    qt6.qtwayland
  ];

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
