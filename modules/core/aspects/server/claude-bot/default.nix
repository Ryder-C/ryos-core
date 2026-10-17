# Claude Discord bot: anyone who saves a card with /billing setup can @mention
# it, and each pays for their own answers through a monthly Stripe invoice.
#
# Host secrets: claude-bot-discord (bot token), claude-bot-anthropic (API key),
# claude-bot-stripe (secret key; sk_test_… while testing).
# The host also sets, in its `aspect.nixos`:
#   services.claude-discord-bot.package  (from the bot's flake)
#   services.claude-discord-bot.settings.guild_id / .admins
{
  ry.claude-bot.nixos = {
    lib,
    secretFile,
    ...
  }: {
    imports = [./_module.nix];

    services.claude-discord-bot = {
      enable = true;

      discordTokenFile = secretFile "claude-bot-discord";
      anthropicApiKeyFile = secretFile "claude-bot-anthropic";
      stripeSecretKeyFile = secretFile "claude-bot-stripe";

      # Everything below is a default the host can override.
      settings = lib.mapAttrsRecursive (_: lib.mkDefault) {
        claude = {
          # claude-sonnet-5-5 or claude-opus-5-5; billed at that model's list price.
          model = "claude-sonnet-5-5";
          # Appended to the built-in prompt (Discord formatting, asker names, date).
          system_prompt = "Keep answers short unless asked for detail. Always disagree with Splunk.";
          max_tokens = 16000;
          max_context_turns = 10;
          web_search = true;
          web_search_max_uses = 5;
          max_images = 4;
        };

        billing = {
          markup = 1.0;
          default_monthly_cap_usd = 25.0;
          min_invoice_usd = 1.0;
          timezone = "America/Los_Angeles";
          unpaid_grace_days = 3;
          return_url = "https://discord.com/app";
        };
      };
    };
  };
}
