# core

Shared NixOS configuration built on [den](https://den.denful.dev) and
flake-parts. Everything reusable lives here as a den *aspect* in the `ry`
namespace; each computer has its own small flake that imports this one and
picks aspects.

## A host flake

```nix
{
  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "praxis";
      system = "x86_64-linux";
      users = ["ryder"];                 # each gets ry.users.<name>
      flakePath = "/home/ryder/praxis";  # for nh and the ns/nst/nsb aliases
      facts.nvidia.open = true;          # typed host facts (modules/core/schema.nix)
      aspects = ry: [
        ry.desktop                       # profile
        ry.nvidia                        # reads host.nvidia.*
        ry.steam ry.steam.presence       # aspect + opt-in sub-aspect
        (ry.charger {device = "BAT0";})  # callable aspect
      ];
      aspect.nixos.imports = [./hardware-configuration.nix];
      aspect.homeManager.programs.niri.settings.outputs = { /* ... */ };
    };
}
```

`nix flake init -t github:Ryder-C/ryos-core#host` scaffolds one; `examples/` has
the real hosts. The host flake needs no other inputs: core's are merged in
underneath, so `nix flake update core` moves nixpkgs, home-manager, den and
every aspect input together. Host-only inputs (a kernel, a hardware module)
are declared in the host flake as usual and used from `aspect`.

`mkHost` returns the full flake outputs: `nixosConfigurations.<name>`, an `nh`
wrapper (`nix run .#<name> -- switch`), `formatter`, and `denful.ry`. A host
that wants raw den/flake-parts imports `core.flakeModules.default` instead.

## How aspects take options

| Kind | Used for | Example |
|---|---|---|
| host facts | hardware truths several aspects read | `facts.nvidia = { open = false; driver = "legacy_580"; }` |
| sub-aspects (`provides`) | optional parts of an aspect | `ry.editor.helix`, `ry.nixflix.onepace`, `ry.flatpak.sober` |
| callable aspects | one aspect, one parameter set | `ry.charger { device = "macsmc-battery"; }`, `ry.rgb { motherboard = "intel"; }` |
| quirks | many producers, one consumer | any aspect emits `homepage`/`vhost` entries; `ry.homepage`/`ry.caddy` render them |

Facts are declared in `modules/core/schema.nix`; quirks in `modules/core/quirks.nix`.

## Secrets

Account-scoped secrets (`pia`, `cloudflare-api-token`, `steam_key`,
`google-maps`) are agenix files in `secrets/`, decryptable by the hosts listed
in `secrets/secrets.nix` (add a host key there and `agenix -r` to onboard one).

Instance-local secrets (arr API keys, admin passwords, vaultwarden env) are
supplied by the private host flake as `facts.secrets.<name>`, either a string
or a path. Aspects consume them through the `secretFile`/`secretValue` module
arguments; a host-supplied value always wins over the agenix fallback. Either
form ends up world-readable in `/nix/store` on that host, which is the same
exposure the previous config had for the hardcoded arr keys. Each aspect's
header comment lists the names it needs; `examples/fornax` shows the full set.

## Layout

```
modules/core/      exported to hosts as flakeModules.default
  den.nix defaults.nix schema.nix quirks.nix profiles.nix devshell.nix
  users/           ry.users.ryder, ry.users.adin
  aspects/{system,cli,desktop,virt,games,server}/<name>.nix   one aspect per file
modules/flake/     core-only: flake-file wiring, mkHost, CI hosts, dev shell
secrets/ wallpapers/ templates/host/ examples/<host>/
```

Every aspect declares the flake inputs it uses next to itself
(`flake-file.inputs.*`); `flake.nix` is generated with `nix run .#write-flake`.

Profiles: `ry.base` (headless-capable), `ry.desktop` (niri + noctalia
workstation), `ry.server` (base + ssh, never sleeps).

## Checks

`nix flake check` evaluates three sample hosts assembled through `mkHost`
(`ci-desktop`, `ci-laptop`, `ci-server`) so every aspect is exercised, and runs
deadnix/statix/alejandra. Note `pkgs.caddy.withPlugins` needs
`builtins.convertHash`, which lix does not provide; evaluate the server host
with upstream nix (`nix shell nixpkgs#nixVersions.latest -c nix ...`).

## Migrating from the old repo

- Decrypt the fornax-only `.age` files once (`agenix -d <name>.age` in the old
  repo) and move the values into that host's `facts.secrets`.
- The cross-seed service was already gone; its user, tmpfiles entry and the
  `nixarr` input are dropped. qBittorrent's finished-download webhook stays,
  enabled only when a `cross-seed` secret is present.
- Removed as unused: `firejail`, `permittedInsecurePackages = ["libsoup-2.74.3"]`
  (nothing in the praxis closure references it), `icu`, `qbit-manage`,
  `shoko`, nix-darwin/umbra.
- `home-manager.backupCommand = "rm -f"` is kept but note it deletes files
  that are in the way of a switch.
