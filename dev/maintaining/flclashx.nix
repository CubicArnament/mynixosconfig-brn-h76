{ appimageTools, fetchurl, lib }:

appimageTools.wrapType2 rec {
  pname = "flclashx";
  version = "0.4.2";

  src = fetchurl {
    url = "https://github.com/pluralplay/FlClashX/releases/download/v${version}/FlClashX-linux-amd64.AppImage";
    hash = "sha256-jKqfL1kradD06uCrXxdpeJDRTvL65IF7S9A0I1CzA8I=";
  };

  meta = {
    description = "Cross-platform proxy client based on Mihomo Core";
    homepage = "https://github.com/pluralplay/FlClashX";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
