{
  den,
  inputs,
  lib,
  ...
}: let
  rylib = import ./_lib.nix;

  # Secrets come from the host flake (`facts.secrets`, plaintext) or, for the
  # few account-scoped ones shipped in core, from agenix.
  secretArgs = {
    host,
    config,
    pkgs,
  }: {
    # Path to a file holding the secret.
    secretFile = name: let
      v = rylib.hostSecret host name;
    in
      if v == null
      then (config.age.secrets.${name}.path or (rylib.missingSecret host name))
      else if builtins.isPath v
      then v
      else pkgs.writeText "secret-${name}" v;

    # The literal secret, for configs that cannot read a file at runtime.
    secretValue = rylib.secretValue host;

    # `age.secrets = ageSecret "name" { owner = ...; }` declares the agenix
    # fallback shipped in core/secrets, but only when the host did not
    # supply the secret itself (agenix would otherwise fail to decrypt it).
    ageSecret = name: extra:
      lib.mkIf (rylib.hostSecret host name == null) {
        ${name} = {file = ./../../secrets + "/${name}.age";} // extra;
      };
  };

  stableFor = system: overlays:
    import inputs.nixpkgs-stable {
      inherit system overlays;
      config.allowUnfree = true;
    };
in {
  den.default = {
    includes = [
      den._.define-user
      den._.hostname
    ];

    nixos = {
      host,
      config,
      pkgs,
      ...
    }: {
      system.stateVersion = lib.mkDefault "24.05";
      _module.args =
        secretArgs {inherit host config pkgs;}
        // {
          # Same overlays as the unstable set, applied lazily, so an aspect
          # that overlays e.g. a CUDA-enabled btop gets it from stablePkgs too.
          stablePkgs = stableFor pkgs.stdenv.hostPlatform.system config.nixpkgs.overlays;
        };

      home-manager = {
        useUserPackages = true;
        useGlobalPkgs = true;
      };
    };

    homeManager = {
      osConfig,
      pkgs,
      ...
    }: {
      home.stateVersion = lib.mkDefault "24.05";
      programs.home-manager.enable = true;
      _module.args.stablePkgs = stableFor pkgs.stdenv.hostPlatform.system osConfig.nixpkgs.overlays;
    };
  };
}
