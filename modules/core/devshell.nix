# `nix fmt` for core and for every host built with mkHost.
{
  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;
  };
}
