{inputs, ...}: {
  flake-file.inputs.spicetify-nix = {
    url = "github:gerg-l/spicetify-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.spotify.homeManager = {pkgs, ...}: let
    spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  in {
    imports = [inputs.spicetify-nix.homeManagerModules.default];

    home.packages = [pkgs.spotify-player];

    programs.spicetify = {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblock
        hidePodcasts
        shuffle
        fullAppDisplay
      ];
      theme = spicePkgs.themes.catppuccin;
      colorScheme = "mocha";
    };
  };
}
