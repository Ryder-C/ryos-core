{inputs, ...}: {
  flake-file.inputs.apple-silicon-support.url = "github:nix-community/nixos-apple-silicon/main";

  # Asahi NixOS on an M-series Mac. Display outputs, battery device and the
  # like stay with the host.
  ry.apple-silicon.nixos = {
    pkgs,
    config,
    lib,
    ...
  }: let
    # Inhibit the internal Apple keyboard whenever a bluetooth keyboard is
    # connected. Bluetooth is bustype 0005; keyboards are told apart from mice
    # by their much longer key capability bitmask.
    toggleInternalKb = pkgs.writeShellScript "toggle-internal-kb" ''
      bt_kb_connected=false
      for dev in /sys/class/input/input*/; do
        [ -d "$dev" ] || continue
        bustype=$(cat "$dev/id/bustype" 2>/dev/null) || continue
        [ "$bustype" = "0005" ] || continue
        keys=$(cat "$dev/capabilities/key" 2>/dev/null) || continue
        if [ "''${#keys}" -gt 20 ]; then
          bt_kb_connected=true
          break
        fi
      done

      for dev in /sys/class/input/input*/; do
        [ -d "$dev" ] || continue
        name=$(cat "$dev/name" 2>/dev/null) || continue
        case "$name" in
          *Apple*Keyboard*|*apple*keyboard*)
            if [ "$bt_kb_connected" = true ]; then
              echo 1 > "$dev/inhibited" 2>/dev/null
            else
              echo 0 > "$dev/inhibited" 2>/dev/null
            fi
            ;;
        esac
      done
    '';
  in {
    imports = [inputs.apple-silicon-support.nixosModules.apple-silicon-support];

    boot = {
      extraModprobeConfig = "options appledrm show_notch=1";
      binfmt.emulatedSystems = ["x86_64-linux"];
      # m1n1/U-Boot own the EFI variables.
      loader.efi.canTouchEfiVariables = lib.mkForce false;
      kernelModules = ["acpi_call"];
      extraModulePackages = [config.boot.kernelPackages.acpi_call];
    };

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="${toggleInternalKb}"
      ACTION=="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="${toggleInternalKb}"
    '';

    nix.settings = {
      substituters = ["https://nixos-apple-silicon.cachix.org"];
      trusted-public-keys = [
        "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
      ];
    };
  };
}
