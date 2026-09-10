let
  rylib = import ../../_lib.nix;
in {
  ry.docker = {
    includes = [(rylib.groups ["docker"])];
    nixos.virtualisation = {
      containers.enable = true;
      docker = {
        enable = true;
        autoPrune.enable = true;
      };
      oci-containers.backend = "docker";
    };
  };
}
