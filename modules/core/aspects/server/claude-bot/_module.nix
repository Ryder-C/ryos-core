# NixOS module for the Claude Discord bot. Options only plus the unit; the
# package comes from the bot's own flake, which the host flake brings in.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.claude-discord-bot;
  toml = pkgs.formats.toml {};
  configFile = toml.generate "claude-discord-bot.toml" cfg.settings;

  # credential name -> (option, env var the bot reads through `<VAR>_FILE`)
  secrets = {
    discord_token = {
      file = cfg.discordTokenFile;
      var = "DISCORD_TOKEN";
    };
    anthropic_api_key = {
      file = cfg.anthropicApiKeyFile;
      var = "ANTHROPIC_API_KEY";
    };
    stripe_secret_key = {
      file = cfg.stripeSecretKeyFile;
      var = "STRIPE_SECRET_KEY";
    };
  };
  givenSecrets = lib.filterAttrs (_: s: s.file != null) secrets;

  secretFileOption = what:
    lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File containing the ${what}. Passed to the service as a systemd
        credential, so it may be root-only. Leave null to supply it through
        `environmentFile` instead.
      '';
    };
in {
  options.services.claude-discord-bot = {
    enable = lib.mkEnableOption "the Claude Discord bot";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The bot, from its flake: `inputs.claude-discord-bot.packages.\${system}.default`.";
    };

    settings = lib.mkOption {
      description = ''
        Bot configuration, written to TOML (see config.example.toml in the bot
        repo). The bot rejects unknown keys at startup. No secrets here: this
        file is in the Nix store.
      '';
      default = {};
      type = lib.types.submodule {
        freeformType = toml.type;
        options = {
          guild_id = lib.mkOption {
            type = lib.types.ints.positive;
            description = "ID of the Discord server the bot answers in.";
          };
          admins = lib.mkOption {
            type = lib.types.listOf lib.types.ints.positive;
            default = [];
            description = "Discord user IDs allowed to manage the whitelist and billing.";
          };
          database_path = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/claude-discord-bot/bot.db";
          };
        };
      };
    };

    discordTokenFile = secretFileOption "Discord bot token";
    anthropicApiKeyFile = secretFileOption "Anthropic API key";
    stripeSecretKeyFile = secretFileOption "Stripe secret key (sk_test_… or sk_live_…)";

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/claude-discord-bot.env";
      description = ''
        Optional KEY=value file read by systemd, an alternative to the *File
        options (DISCORD_TOKEN, ANTHROPIC_API_KEY, STRIPE_SECRET_KEY). A string,
        not a path, so it is never copied into the store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (_: s: {
        assertion = s.file != null || cfg.environmentFile != null;
        message = "services.claude-discord-bot: no source for ${s.var}; set its *File option or environmentFile.";
      })
      secrets;

    systemd.services.claude-discord-bot = {
      description = "Claude Discord bot";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];

      environment =
        {RUST_LOG = lib.mkDefault "info,serenity=warn,poise=warn";}
        # %d is the unit's credentials directory.
        // lib.mapAttrs' (name: s: lib.nameValuePair "${s.var}_FILE" "%d/${name}") givenSecrets;

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} ${configFile}";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        LoadCredential = lib.mapAttrsToList (name: s: "${name}:${s.file}") givenSecrets;
        Restart = "on-failure";
        RestartSec = 10;

        DynamicUser = true;
        StateDirectory = "claude-discord-bot";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/claude-discord-bot";

        # Hardening: outbound HTTPS, DNS and its state directory, nothing else.
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        # AF_UNIX for nscd/resolved lookups.
        RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = ["@system-service" "~@privileged"];
        UMask = "0077";
      };
    };
  };
}
