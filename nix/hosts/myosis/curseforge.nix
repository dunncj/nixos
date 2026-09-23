{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  runCommand,
  unzip,
}:

let
  pname = "curseforge";
  version = "1.285.2-27841";

  zip = fetchurl {
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.zip";
    hash = "sha256-ksxrZLY0dYHCWTHsoyr0o5PEbGjGQ2IWqrXl43J/ASE=";
  };

  src = runCommand "CurseForge-${version}.AppImage" { nativeBuildInputs = [ unzip ]; } ''
    unzip -p ${zip} 'CurseForge-*.AppImage' > $out
  '';

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraPkgs =
    pkgs:
    lib.singleton (
      pkgs.curl.overrideAttrs (old: {
        configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-versioned-symbols" ];
      })
    );

  extraInstallCommands = ''
    wrapProgram $out/bin/curseforge \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
    install -Dm444 ${contents}/curseforge.desktop -t $out/share/applications/
    cp -r ${contents}/usr/share/icons $out/share/icons
    substituteInPlace $out/share/applications/curseforge.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=curseforge %U'
  '';

  meta = {
    description = "CurseForge mod and modpack manager";
    homepage = "https://www.curseforge.com/download/app";
    license = lib.licenses.unfree;
    mainProgram = "curseforge";
    platforms = [ "x86_64-linux" ];
  };
}
