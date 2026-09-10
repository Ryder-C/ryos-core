{inputs, ...}: {
  flake-file.inputs.nix-yazi-plugins = {
    url = "github:lordkekz/nix-yazi-plugins";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.yazi.homeManager = {
    host,
    pkgs,
    ...
  }: {
    imports = [inputs.nix-yazi-plugins.legacyPackages.${host.system}.homeManagerModules.default];

    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
      plugins = {inherit (pkgs.yaziPlugins) yatline-catppuccin rich-preview;};
      settings.opener.edit = [
        {
          run = "nvim \"$@\"";
          block = true;
          for = "unix";
        }
      ];
      yaziPlugins = {
        enable = true;
        plugins = {
          starship.enable = true;
          jump-to-char = {
            enable = true;
            keys.toggle.on = ["F"];
          };
          bookmarks.enable = true;
        };
      };
    };
  };
}
