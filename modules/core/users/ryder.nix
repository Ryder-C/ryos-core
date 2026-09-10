{
  den,
  ry,
  ...
}: {
  ry.users.ryder = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
      # Host aspects' homeManager content is projected onto this user.
      den._.host-aspects
      ry.agenix
    ];

    nixos = {config, ...}: {
      users.users.ryder = {
        description = "ryder";
        # Keep user services (libvirt sessions, timers) alive across logout.
        linger = true;
      };
      nix.settings.allowed-users = ["ryder"];

      # ryder's SSH key is what agenix decrypts core secrets with.
      age.identityPaths = ["${config.users.users.ryder.home}/.ssh/id_ed25519"];
    };
  };
}
