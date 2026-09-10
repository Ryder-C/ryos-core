# Host flake

1. `nix flake init -t github:Ryder-C/ryos-core#host`
2. Copy `/etc/nixos/hardware-configuration.nix` next to `flake.nix`.
3. Replace `CHANGEME`, pick aspects, add facts.
4. `nix run .#CHANGEME -- switch` (an `nh` wrapper) or `nixos-rebuild switch --flake .`.
