{
  den,
  inputs,
  ...
}: {
  flake-file.inputs.adin-configs.url = "github:AdinAck/nix-configs";

  ry.users.adin = {
    includes = [
      den._.primary-user
      (den._.user-shell "fish")
    ];

    nixos = {
      # Adin's system-level GNOME (xserver + gdm + gnome desktop, host-wide).
      imports = [inputs.adin-configs.system-aspects.gnome];

      users.users.adin = {
        description = "adin";
        extraGroups = ["dialout" "input" "uinput" "seat" "docker"];
        initialPassword = "adin123";
      };
      nix.settings.allowed-users = ["adin"];
    };

    homeManager = {
      # All of Adin's home-manager aspects.
      imports = builtins.attrValues inputs.adin-configs.user-aspects;
    };
  };
}
