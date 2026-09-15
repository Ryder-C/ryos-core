# arr-mcp: one MCP endpoint over the whole stack, plus the client entry that
# registers it with claude-code/opencode (programs.mcp, see ry.ai). Both halves
# live here because the token they share is minted by the container's unit.
# Host secrets: radarr-api, sonarr-api, sonarr-anime-api, prowlarr-api,
# bazarr-api, jellyfin-api, seerr-api.
let
  port = 6060;
  user = "ryder";

  # The bearer token lives here and nowhere else: not in a repo, not in the
  # store, not in an age file. The unit mints it once, renders it into
  # arr-mcp's config.yaml on every start, and the login shell exports it so
  # claude-code can expand it out of the environment -- so both ends of the
  # connection read the same runtime file and cannot drift apart.
  # Deliberately outside /var/lib/arr-mcp: that directory is the container's
  # /config volume, and arr-mcp's entrypoint chowns it recursively to PUID:PGID
  # on every start -- which takes the file straight back off ${user}.
  tokenFile = "/var/lib/arr-mcp-token";
  tokenEnv = "ARR_MCP_TOKEN";
in {
  nixos = {
    config,
    pkgs,
    secretFile,
    ...
  }: let
    # Everything but the auth block, which preStart prepends -- see below.
    # Placeholders are filled from the host secrets at start.
    servicesYamlTemplate = pkgs.writeText "arr-mcp-services.yaml.template" ''
      # Read-only by default: every service takes an optional
      #   permissions: {safe_write: true, destructive: true}
      # block, and both flags default to false, so the MCP tools that add,
      # delete or trigger anything are refused until one is set here.
      services:
        radarr:
          url: "http://localhost:7878"
          api_key: "@RADARR_API_KEY@"
        # Two Sonarrs means the list form, and every read is labelled with the
        # instance it came from (`sonarr/anime`). Writes then have to name one.
        sonarr:
          - name: tv
            url: "http://localhost:8989"
            api_key: "@SONARR_API_KEY@"
          - name: anime
            url: "http://localhost:8990"
            api_key: "@SONARR_ANIME_API_KEY@"
        prowlarr:
          url: "http://localhost:9696"
          api_key: "@PROWLARR_API_KEY@"
        bazarr:
          url: "http://localhost:6767"
          api_key: "@BAZARR_API_KEY@"
        jellyfin:
          url: "http://localhost:8096"
          api_key: "@JELLYFIN_API_KEY@"
          default_user: "ryder"
        seerr:
          url: "http://localhost:5055"
          api_key: "@SEERR_API_KEY@"
        # No credentials on purpose: ry.torrents sets WebUI\LocalHostAuth=false,
        # and the container shares the host's network namespace.
        qbittorrent:
          url: "http://localhost:8080"
    '';
  in {
    systemd.tmpfiles.rules = [
      # 0700: config.yaml and the audit trail hold an API key for every
      # service in the stack. The token ${user} needs lives outside this
      # directory -- see tokenFile above.
      "d /var/lib/arr-mcp 0700 root root - -"
    ];

    systemd.services."${config.virtualisation.oci-containers.backend}-arr-mcp" = {
      after = ["radarr.service" "sonarr.service" "sonarr-anime.service" "jellyfin.service"];

      # arr-mcp keeps its whole configuration in one config.yaml, the config
      # UI writes to that same file, and the process rewrites it on startup
      # when a field is missing -- so it cannot be mounted read-only out of
      # the store.
      #
      # Render it here on every start instead: everything below is
      # declarative, and a save from the config UI is overwritten on the next
      # restart. The one field carried over is the UI's password hash, which
      # only the setup page can produce -- regenerating without it would
      # un-claim the instance on every rebuild, handing the setup page back to
      # whoever loads it next.
      preStart = ''
        umask 0077
        cfg=/var/lib/arr-mcp/config.yaml

        # Minted here rather than left to arr-mcp's own first-run generation,
        # which only ever lands in the root-owned config.yaml -- the client
        # needs a file it can read.
        if [ ! -s ${tokenFile} ]; then
          # An existing token wins, so adopting this file does not invalidate
          # clients that were configured against a previously generated one.
          if [ -e "$cfg" ]; then
            sed -n 's/^[[:space:]]*bearer_token:[[:space:]]*//p' "$cfg" | head -1 | tr -d "\"'" > ${tokenFile}
          fi
          if [ ! -s ${tokenFile} ]; then
            ${pkgs.openssl}/bin/openssl rand -hex 32 > ${tokenFile}
          fi
        fi
        chown ${user} ${tokenFile}
        chmod 0400 ${tokenFile}

        hash=""
        if [ -e "$cfg" ]; then
          hash=$(sed -n 's/^[[:space:]]*password_hash:[[:space:]]*//p' "$cfg" | head -1 | tr -d "\"'")
        fi

        {
          echo "# Generated on every start by ry.nixflix.arr-mcp (_arr-mcp.nix)."
          echo "# Edit that file, not this one."
          echo "auth:"
          echo "  username: admin"
          echo "  bearer_token: $(cat ${tokenFile})"
          if [ -n "$hash" ]; then echo "  password_hash: $hash"; fi
          sed \
            -e "s|@RADARR_API_KEY@|$(cat ${secretFile "radarr-api"})|" \
            -e "s|@SONARR_API_KEY@|$(cat ${secretFile "sonarr-api"})|" \
            -e "s|@SONARR_ANIME_API_KEY@|$(cat ${secretFile "sonarr-anime-api"})|" \
            -e "s|@PROWLARR_API_KEY@|$(cat ${secretFile "prowlarr-api"})|" \
            -e "s|@BAZARR_API_KEY@|$(cat ${secretFile "bazarr-api"})|" \
            -e "s|@JELLYFIN_API_KEY@|$(cat ${secretFile "jellyfin-api"})|" \
            -e "s|@SEERR_API_KEY@|$(cat ${secretFile "seerr-api"})|" \
            ${servicesYamlTemplate}
        } > "$cfg.tmp"
        mv "$cfg.tmp" "$cfg"
      '';
    };

    virtualisation.oci-containers.containers.arr-mcp = {
      image = "ghcr.io/bardesss/arr-mcp:latest";
      environment = {
        # The entrypoint chowns /config and then drops to these ids; the state
        # dir is root-owned, and the *arrs are reached over loopback anyway.
        PUID = "0";
        PGID = "0";
        ARR_MCP_PORT = toString port;
        TZ = "America/Los_Angeles";
      };
      volumes = ["/var/lib/arr-mcp:/config"];
      # Host networking so localhost reaches the stack. arr-mcp always binds
      # 0.0.0.0, so :6060 is on every interface -- the firewall is deliberately
      # not opened for it. Until a password is set the instance is *unclaimed*,
      # and whoever loads the setup page first owns it, config.yaml included.
      extraOptions = ["--network=host"];
    };
  };

  # Registers the endpoint with claude-code (and opencode) through the shared
  # programs.mcp servers (ry.ai), which is what `claude mcp add` would
  # otherwise have written into ~/.claude.json by hand. Only hosts that run
  # the aspect get it.
  homeManager = {osConfig, ...}: {
    programs.mcp.servers.arr-mcp = {
      url = "http://${osConfig.networking.hostName}:${toString port}/mcp";
      # Left unexpanded on purpose: claude-code substitutes $ARR_MCP_TOKEN
      # from the environment when it reads the generated .mcp.json, so the
      # store copy of that file holds the variable's name, never the token.
      headers.Authorization = "Bearer \${${tokenEnv}}";
    };

    programs.fish.shellInit = ''
      # Readable only by ${user}, and only on the host running the container;
      # elsewhere the variable stays unset and the server just fails to connect.
      if test -r ${tokenFile}
        set -gx ${tokenEnv} (cat ${tokenFile})
      end
    '';
  };
}
