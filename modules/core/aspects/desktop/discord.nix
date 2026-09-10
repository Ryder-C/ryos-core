{inputs, ...}: {
  flake-file.inputs.nixcord = {
    url = "github:kaylorben/nixcord";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Discord ships no aarch64-linux build.
  ry.discord.homeManager = {
    imports = [inputs.nixcord.homeModules.nixcord];

    programs.nixcord = {
      enable = true;
      discord = {
        enable = true;
        vencord.enable = false;
        equicord.enable = true;
      };
      equibop.enable = false;
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
