{
  bash,
  commandScripts,
  coreutils,
  homeManager,
  homeProfile,
  jq,
  makeWrapper,
  nix,
  shadow,
  stdenvNoCC,
  systemd,
  hostName,
  ...
}:

stdenvNoCC.mkDerivation {
  pname = "nixos-helper";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    ${bash}/bin/bash -n nixos-helper.sh nix-prefetch-maintaining.sh ${commandScripts}/*.sh

    mkdir -p $out/bin $out/libexec/nixos-helper
    install -m 755 nixos-helper.sh $out/bin/nixos-helper
    install -m 755 nix-prefetch-maintaining.sh $out/bin/nix-prefetch-maintaining
    install -m 755 ${commandScripts}/*.sh $out/libexec/nixos-helper/

    wrapProgram $out/bin/nixos-helper \
      --prefix PATH : $out/bin:${bash}/bin:${coreutils}/bin:${homeManager}/bin:${nix}/bin:${shadow}/bin:${systemd}/bin \
      --set NIXOS_HELPER_FLAKE "path:/etc/nixos#${hostName}" \
      --set NIXOS_HELPER_HOME_FLAKE "path:/etc/nixos#${homeProfile}" \
      --set NIXOS_HELPER_COMMANDS_DIR "$out/libexec/nixos-helper"

    wrapProgram $out/bin/nix-prefetch-maintaining \
      --prefix PATH : ${bash}/bin:${jq}/bin:${nix}/bin
  '';
}
