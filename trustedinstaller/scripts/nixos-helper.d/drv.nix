{
  bash,
  coreutils,
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
    ${bash}/bin/bash -n nixos-helper.sh nix-prefetch-maintaining.sh

    mkdir -p $out/bin
    install -m 755 nixos-helper.sh $out/bin/nixos-helper
    install -m 755 nix-prefetch-maintaining.sh $out/bin/nix-prefetch-maintaining

    wrapProgram $out/bin/nixos-helper \
      --prefix PATH : $out/bin:${bash}/bin:${coreutils}/bin:${nix}/bin:${shadow}/bin:${systemd}/bin \
      --set NIXOS_HELPER_FLAKE "/etc/nixos#${hostName}"

    wrapProgram $out/bin/nix-prefetch-maintaining \
      --prefix PATH : ${bash}/bin:${jq}/bin:${nix}/bin
  '';
}
