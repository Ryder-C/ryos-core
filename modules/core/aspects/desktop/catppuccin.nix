{inputs, ...}: {
  flake-file.inputs = {
    catppuccin.url = "github:catppuccin/nix";
    catppuccin-stylus-json = {
      url = "https://github.com/catppuccin/userstyles/releases/download/all-userstyles-export/import.json";
      flake = false;
    };
  };

  # Catppuccin Mocha / Mauve everywhere: catppuccin/nix for what it covers,
  # plus GTK theme, cursors, icons and the Stylus export for the browser.
  ry.catppuccin = {
    nixos = {
      imports = [inputs.catppuccin.nixosModules.catppuccin];
      programs.dconf.enable = true;
      catppuccin = {
        enable = true;
        autoEnable = true;
        cache.enable = true;
        flavor = "mocha";
        accent = "mauve";
        tty.enable = false;
        limine.enable = false;
      };
    };

    homeManager = {
      config,
      pkgs,
      ...
    }: let
      # nixpkgs removed every murrine-based GTK theme on 2026-07-22, including
      # magnetic-catppuccin-gtk. murrine was only a GTK2 runtime dep, so build
      # it here without it.
      catppuccin-gtk = pkgs.stdenvNoCC.mkDerivation {
        pname = "catppuccin-gtk-theme";
        version = "0-unstable-2026-06-25";

        src = pkgs.fetchFromGitHub {
          owner = "Fausto-Korpsvart";
          repo = "Catppuccin-GTK-Theme";
          rev = "a0f69cc33299dc97267c3507fe8a001aecc46b0f";
          hash = "sha256-bSEWm62EWHC9zcYA+YoQp2cuSFt2FDsjalapnjYdoYU=";
        };

        nativeBuildInputs = with pkgs; [jdupes sassc];
        postPatch = "patchShebangs themes";
        dontBuild = true;

        # BATCH_MODE skips the installer's interactive "apply now?" prompt, and
        # the long accent flag is --theme despite what --help claims.
        installPhase = ''
          runHook preInstall
          export HOME=$TMPDIR
          mkdir -p $out/share/themes
          BATCH_MODE=true ./themes/install.sh \
            --name Catppuccin \
            --theme mauve \
            --mode dark \
            --size standard \
            --dest $out/share/themes
          jdupes --quiet --link-soft --recurse $out/share
          runHook postInstall
        '';
      };
    in {
      imports = [inputs.catppuccin.homeModules.catppuccin];

      catppuccin = {
        enable = true;
        autoEnable = true;
        cache.enable = true;
        accent = "mauve";
        flavor = "mocha";
        cava.transparent = true;
        cursors = {
          enable = true;
          accent = "dark";
        };
      };

      home = {
        # catppuccin.cursors sets home.pointerCursor.* but not `.enable`; HM
        # now requires the explicit toggle instead of inferring it.
        pointerCursor.enable = true;

        packages = with pkgs; [
          dracula-icon-theme
          adwaita-icon-theme
        ];

        # Catppuccin Stylus export, patched to keep YouTube video backgrounds black.
        file."catppuccin_styles.json".source =
          pkgs.runCommand "catppuccin-stylus-patched.json" {
            nativeBuildInputs = [pkgs.jq];
          } ''
            jq '
              map(
                if .name == "YouTube Catppuccin" then
                  .sourceCode += "\n/* Override: keep video letterbox bars black */\nvideo, video::backdrop, .html5-video-player, .html5-video-container { background-color: #000 !important; }\n"
                else . end
              )
            ' ${inputs.catppuccin-stylus-json} > $out
          '';
      };

      gtk = {
        enable = true;
        theme = {
          name = "Catppuccin-Mauve-Dark";
          package = catppuccin-gtk;
        };
        # HM changed the gtk4 theme default to null; keep theming GTK4 apps.
        gtk4.theme = config.gtk.theme;
        font = {
          name = "FiraCode Nerd Font";
          size = 11;
        };
      };
    };
  };
}
