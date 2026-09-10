{
  inputs,
  ry,
  ...
}: {
  flake-file.inputs.ryguessr.url = "github:AdinAck/ryguessr";

  ry.guessr = {
    includes = [ry.agenix];

    nixos = {
      secretFile,
      ageSecret,
      ...
    }: {
      imports = [inputs.ryguessr.nixosModules.default];

      age.secrets = ageSecret "google-maps" {};

      services.ryguessr = {
        enable = true;
        googleMapsApiKeyFile = secretFile "google-maps";
        bindAddr = "127.0.0.1:3000";
      };
    };

    vhost = {
      domain = "ryder.rs";
      sub = "guessr";
      port = 3000;
    };
  };
}
