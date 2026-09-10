{
  inputs,
  ry,
  ...
}: {
  flake-file.inputs.nix-pia-vpn = {
    url = "github:rcambrj/nix-pia-vpn";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # qBittorrent bound to a PIA WireGuard tunnel with port forwarding, plus
  # `vpn-full on|off` to route the whole host through it. Needs the `pia`
  # secret (core agenix by default). If a `cross-seed` secret ({ apiKey })
  # is present, finished downloads are announced to a cross-seed daemon.
  ry.torrents = {
    includes = [ry.agenix];

    nixos = {
      host,
      pkgs,
      secretFile,
      ageSecret,
      ...
    }: let
      hasCrossSeed = host.secrets ? cross-seed;
      crossSeedWebhook = pkgs.writeShellScript "cross-seed-webhook" ''
        API_KEY=$(${pkgs.jq}/bin/jq -r '.apiKey' ${secretFile "cross-seed"})
        ${pkgs.curl}/bin/curl -XPOST "http://localhost:2468/api/webhook?apikey=$API_KEY" -d "infoHash=$1"
      '';
      qbtConfig = pkgs.writeText "qb-config" ''
        [BitTorrent]
        Session\DefaultSavePath=/storage/Torrents
        Session\Interface=wg0
        Session\InterfaceName=wg0
        Session\AsyncIOThreadsCount=64
        Session\CoalesceReadWrite=true
        Session\DiskCacheSize=2048
        Session\DiskCacheTTL=60
        Session\DiskIOReadMode=DisableOSCache
        Session\DiskIOType=Default
        Session\DiskIOWriteMode=EnableOSCache
        Session\DiskQueueSize=67108864
        Session\PieceExtentAffinity=true
        Session\SendBufferLowWatermark=2048
        Session\SendBufferWatermark=8192
        Session\SendBufferWatermarkFactor=120
        Session\SuggestMode=true

        [Core]
        AutoDeleteAddedTorrentFile=IfAdded

        [LegalNotice]
        Accepted=true

        [Preferences]
        General\Locale=en
        WebUI\LocalHostAuth=false
        WebUI\Password_PBKDF2="@ByteArray(iCp/Z6bCKxlKKvdo2V83DA==:gl77/ciU/P+lQpul2KktZyuAj0ulk0lamAnsPSa4cjyD4fgojn
          +et4ctn1cOEa6ACbI+gSp/1+cw4OBbUiVtQtg==)"
        ${
          if hasCrossSeed
          then ''
            Downloads\OnFinish\Enabled=true
            Downloads\OnFinish\Program=${crossSeedWebhook} "%I"
          ''
          else ""
        }
      '';
      profileBase = "/var/lib/qbittorrent";
      profName = "vpn";
      piaCertPath = "/etc/pia/ca.rsa.4096.crt";

      vpn-full = pkgs.writeShellApplication {
        name = "vpn-full";
        runtimeInputs = with pkgs; [nftables iproute2 jq wireguard-tools systemd gawk sudo];
        text = builtins.readFile ./_vpn-full.sh;
      };
    in {
      imports = [inputs.nix-pia-vpn.nixosModules.default];

      age.secrets = ageSecret "pia" {};

      environment.etc."pia/ca.rsa.4096.crt" = {
        source = ./ca.rsa.4096.crt;
        mode = "0444";
      };

      users.groups.media = {};

      environment.systemPackages = [vpn-full];

      systemd = {
        tmpfiles.rules = [
          "d ${profileBase} 0755 root root - -"
        ];
        services = {
          vpn-full = {
            description = "Route all traffic through PIA wg0 (kill switch)";
            # Tie lifetime to pia-vpn so a wg0 restart re-applies routes + nft rules.
            bindsTo = ["pia-vpn.service"];
            after = ["pia-vpn.service"];
            # Manually started via `vpn-full on`; never enabled by default.
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${vpn-full}/bin/vpn-full _apply";
              ExecStop = "${vpn-full}/bin/vpn-full _revert";
            };
          };
          pia-vpn-portforward.unitConfig.RequiresMountsFor = "/storage";
          pia-vpn = {
            enable = true;
            wants = [
              "network-online.target"
              "NetworkManager-wait-online.service"
              "systemd-resolved.service"
            ];
            after = [
              "network-online.target"
              "NetworkManager-wait-online.service"
              "systemd-resolved.service"
            ];
            serviceConfig = {
              ExecStartPre = pkgs.writeShellScript "pia-wait-dns" ''
                #!${pkgs.runtimeShell}
                for i in $(seq 1 15); do
                  ${pkgs.systemd}/bin/resolvectl query serverlist.piaservers.net >/dev/null 2>&1 && exit 0
                  ${pkgs.coreutils}/bin/sleep 1
                done
                exit 0
              '';
              Restart = "on-failure";
              RestartSec = "5s";
              StartLimitBurst = 10;
            };
          };
        };
      };

      services.pia-vpn = {
        enable = true;
        certificateFile = piaCertPath;
        region = "ca_vancouver";
        environmentFile = secretFile "pia";

        portForward = {
          enable = true;
          script = ''
            mkdir -p ${profileBase}/qBittorrent_${profName}
            rm -f ${profileBase}/qBittorrent_${profName}/qBittorrent.conf
            cp ${qbtConfig} ${profileBase}/qBittorrent_${profName}/qBittorrent.conf
            umask 0002
            ${pkgs.util-linux}/bin/runuser -u root -g media -- ${pkgs.qbittorrent-nox}/bin/qbittorrent-nox -d --confirm-legal-notice --torrenting-port=$port --profile=${profileBase} --configuration=${profName} || true
          '';
        };
      };
    };

    homepage = {config, ...}: {
      group = "Downloads";
      name = "qBittorrent";
      href = "http://${config.networking.hostName}:7476";
      icon = "qbittorrent";
      widget = {
        type = "qbittorrent";
        url = "http://localhost:8080";
      };
    };
  };
}
