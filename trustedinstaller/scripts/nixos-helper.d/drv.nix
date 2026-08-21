{
  bash,
  commandScripts,
  coreutils,
  formatter,
  findutils,
  gnugrep,
  gnused,
  homeManager,
  homeProfile,
  jq,
  makeWrapper,
  nix,
  shadow,
  stdenvNoCC,
  systemd,
  templateScripts,
  hostName,
  ...
}:

stdenvNoCC.mkDerivation {
  pname = "nix-hlp";
  version = "1.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    ${bash}/bin/bash -n nix-hlp.sh nix-prefetch-maintaining.sh ${commandScripts}/*.sh ${templateScripts}/*.sh

    mkdir -p $out/bin $out/libexec/nix-hlp/commands $out/libexec/nix-hlp/templates
    install -m 755 nix-hlp.sh $out/bin/nix-hlp
    install -m 755 nix-prefetch-maintaining.sh $out/bin/nix-prefetch-maintaining
    install -m 755 ${commandScripts}/*.sh $out/libexec/nix-hlp/commands/
    install -m 755 ${templateScripts}/*.sh $out/libexec/nix-hlp/templates/

    wrapProgram $out/bin/nix-hlp \
      --prefix PATH : $out/bin:${bash}/bin:${coreutils}/bin:${findutils}/bin:${gnugrep}/bin:${gnused}/bin:${homeManager}/bin:${nix}/bin:${shadow}/bin:${systemd}/bin \
      --set NIX_HLP_FLAKE "path:/etc/nixos#${hostName}" \
      --set NIX_HLP_HOME_FLAKE "path:/etc/nixos#${homeProfile}" \
      --set NIX_HLP_COMMANDS_DIR "$out/libexec/nix-hlp/commands" \
      --set NIX_HLP_TEMPLATES_DIR "$out/libexec/nix-hlp/templates" \
      --set NIX_HLP_FORMATTER "${formatter}/bin/treefmt"

    wrapProgram $out/bin/nix-prefetch-maintaining \
      --prefix PATH : ${bash}/bin:${jq}/bin:${nix}/bin
  '';
}
