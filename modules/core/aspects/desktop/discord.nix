{inputs, ...}: {
  flake-file.inputs.nixcord = {
    url = "github:kaylorben/nixcord";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.discord.homeManager = {pkgs, ...}: let
    # The native Discord client has no aarch64-linux build
    # (meta.platforms = x86_64-linux, x86_64-darwin, aarch64-darwin), so on ARM
    # Linux (sputnik/Asahi) fall back to Equibop: an Electron wrapper with
    # Equicord built in. nixcord's shared `config` below still applies to it.
    useEquibop = pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64;
  in {
    imports = [inputs.nixcord.homeModules.nixcord];

    programs.nixcord = {
      enable = true;
      discord = {
        enable = !useEquibop;
        vencord.enable = false;
        equicord.enable = true;
      };
      equibop.enable = useEquibop;
      vesktop.enable = false;

      config = {
        enabledThemeLinks = [
          "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css"
        ];
        frameless = true;
        plugins = {
          gameActivityToggle.enable = true;
          silentTyping.enable = true;
          typingIndicator.enable = true;
          shikiCodeblocks.enable = true;
          declutter.enable = true;
          ghosted.enable = true;
          fakeNitro.enable = true;
        };
      };
    };
  };
}
