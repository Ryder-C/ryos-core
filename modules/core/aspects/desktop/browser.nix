{inputs, ...}: let
  rylib = import ../../_lib.nix;
in {
  flake-file.inputs.helium = {
    url = "github:schembriaiden/helium-browser-nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.browser.homeManager = {pkgs, ...}: let
    helium-upstream = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium;
    # Pin the Chromium password backend so it doesn't flip between
    # gnome-libsecret (niri) and kwallet (Plasma); without this, switching
    # desktops corrupts the per-profile encryption key and wipes logins.
    helium = pkgs.symlinkJoin {
      name = "helium-wrapped-${helium-upstream.version}";
      paths = [helium-upstream];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/helium \
          --add-flags "--password-store=gnome-libsecret"
      '';
      inherit (helium-upstream) meta;
    };
  in {
    imports = [
      (rylib.whenNiri {
        programs.niri.settings.binds."Mod+B".action.spawn = ["helium"];
      })
    ];

    home.packages = [pkgs.brave helium];
    home.sessionVariables.BROWSER = "helium";

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
      };
    };
    # HM refuses to overwrite a mimeapps.list that apps have rewritten.
    xdg.dataFile."applications/mimeapps.list".force = true;
  };
}
