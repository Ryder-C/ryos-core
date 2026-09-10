{ry, ...}: let
  # Ollama truncates to OLLAMA_CONTEXT_LENGTH regardless of what the client
  # asks for, so the server and pi's `contextWindow` have to agree.
  contextLength = 131072;
  model = "qwen3.8:27b";
in {
  ry.ollama = {
    nixos = {
      host,
      pkgs,
      ...
    }: {
      # ollama runs with ProtectSystem=strict and only gets ReadWritePaths on a
      # models dir that already exists, so create it before the unit starts.
      systemd.tmpfiles.rules = [
        "d /storage/models 0755 ollama ollama -"
      ];

      services = {
        ollama = {
          enable = true;
          package =
            if host.hasAspect ry.nvidia
            then pkgs.ollama-cuda
            else pkgs.ollama;
          user = "ollama";
          modelsDir = "/storage/models";
          # Default is 4096, which a coding agent blows through on its system
          # prompt and tool definitions alone.
          environmentVariables.OLLAMA_CONTEXT_LENGTH = toString contextLength;
        };

        open-webui = {
          enable = true;
          port = 8081;
          # Setting `environment` replaces the module's defaults, so carry the
          # telemetry opt-outs along with our own vars.
          environment = {
            SCARF_NO_ANALYTICS = "True";
            DO_NOT_TRACK = "True";
            ANONYMIZED_TELEMETRY = "False";
            OLLAMA_BASE_URL = "http://127.0.0.1:11434";
            WEBUI_AUTH = "False";
          };
        };
      };
    };

    # Point pi at the local ollama.
    homeManager.programs.pi-coding-agent = {
      models.providers.ollama = {
        api = "openai-completions";
        baseUrl = "http://127.0.0.1:11434/v1";
        # ollama ignores the key, but the OpenAI client insists on one.
        apiKey = "ollama";
        models = [
          {
            id = model;
            name = "Qwen3.8 27B (local)";
            reasoning = true;
            contextWindow = contextLength;
          }
        ];
      };

      settings = {
        defaultProvider = "ollama";
        defaultModel = model;
      };
    };
  };
}
