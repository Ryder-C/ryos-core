{ry, ...}: {
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
      # Vendored nix-pia-vpn module, patched for PIA's token API change.
      imports = [./_pia-vpn.nix];

      age.secrets = ageSecret "pia" {};

      environment.etc."pia/ca.rsa.4096.crt" = {
        source = ./ca.rsa.4096.crt;
        mode = "0444";
      };

      # PIA's forwarded port is dynamic, so accept any unprivileged port on the
      # tunnel; PIA only forwards the one leased port from the internet anyway.
      networking.firewall.interfaces.wg0 = let
        ports = [
          {
            from = 1024;
            to = 65535;
          }
        ];
      in {
        allowedTCPPortRanges = ports;
        allowedUDPPortRanges = ports;
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
          # pia-vpn is a oneshot that never notices when PIA's side goes away
          # (server retired, or our key dropped after a server restart), so wg0
          # silently black-holes. Probe the tunnel and reconnect when it's dead;
          # restarting pia-vpn picks a fresh server and re-registers the key.
          pia-vpn-watchdog = {
            description = "Reconnect PIA when wg0 stops passing traffic";
            path = with pkgs; [iputils curl jq systemd coreutils];
            script = ''
              systemctl is-active --quiet pia-vpn.service || exit 0
              vip=$(jq -r .server_vip /var/lib/pia-vpn/wireguard.json)
              alive() {
                ping -q -c 3 -W 2 -I wg0 "$vip" >/dev/null 2>&1 ||
                  curl -s -m 5 --interface wg0 -o /dev/null https://1.1.1.1
              }
              # Three misses 30s apart before acting, so a blip doesn't cost the port.
              for _ in 1 2 3; do
                alive && exit 0
                sleep 30
              done
              echo "wg0 unreachable via $vip; restarting pia-vpn"
              systemctl restart pia-vpn.service
            '';
            serviceConfig.Type = "oneshot";
          };
        };
        timers.pia-vpn-watchdog = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = "5min";
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
          # Runs on every refresh (~15 min). If qBittorrent is already up, push
          # the (possibly new) port through the WebUI API instead of relaunching.
          script = ''
            api=http://localhost:8080/api/v2
            if current=$(${pkgs.curl}/bin/curl -sf -m 5 "$api/app/preferences" | ${pkgs.jq}/bin/jq -er .listen_port); then
              if [ "$current" != "$port" ]; then
                echo "Updating qBittorrent listen port $current -> $port"
                ${pkgs.curl}/bin/curl -sf -m 5 "$api/app/setPreferences" --data-urlencode "json={\"listen_port\":$port}"
              fi
            else
              mkdir -p ${profileBase}/qBittorrent_${profName}
              rm -f ${profileBase}/qBittorrent_${profName}/qBittorrent.conf
              cp ${qbtConfig} ${profileBase}/qBittorrent_${profName}/qBittorrent.conf
              umask 0002
              ${pkgs.util-linux}/bin/runuser -u root -g media -- ${pkgs.qbittorrent-nox}/bin/qbittorrent-nox -d --confirm-legal-notice --torrenting-port=$port --profile=${profileBase} --configuration=${profName} || true
            fi
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
