{{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "happ";
  version = "3.3.6"; # Обновите при необходимости

  # Ссылка на .deb пакет, например:
  # https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.deb
  src = pkgs.fetchurl {
    url = "https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.deb"; 
    hash = "..."; # Получите командой: nix-prefetch-url <url>
  };

  nativeBuildInputs = with pkgs; [ dpkg autoPatchelfHook ];
  
  # Определение необходимых библиотек (может потребоваться корректировка)
  buildInputs = with pkgs; [ stdenv.cc.cc.lib libGL libxcb fontconfig freetype ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    dpkg -x $src .
    cp -r opt/ $out/
    # Ссылка на исполняемый файл
    ln -s $out/opt/happ/bin/Happ $out/bin/happ
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Happ Proxy Utility Client";
    homepage = "https://github.com/Happ-proxy/happ-desktop";
    platforms = platforms.linux;
  };
}
}