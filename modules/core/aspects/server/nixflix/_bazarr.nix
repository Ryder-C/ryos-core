# Subtitles, with a GPU Whisper container for AI-generated ones.
# Host secret: bazarr-api (homepage widget).
{host, ...}: let
  rylib = import ../../../_lib.nix;
  whisperPort = 9000;
in {
  nixos = {
    services.bazarr = {
      enable = true;
      group = "media";
      # Kept alongside the other service state on the root NVMe -- see the
      # stateDir comment in ./default.nix for why none of this belongs on
      # /storage.
      dataDir = "/var/lib/nixflix/bazarr";
    };

    # CDI device passthrough so the Whisper container can reach the GPU. The
    # toolkit generates the CDI spec against the driver ry.nvidia installs.
    hardware.nvidia-container-toolkit.enable = true;

    # Whisper ASR webservice backs Bazarr's Whisper provider. Set it up in
    # Bazarr: Providers -> Whisper, http://127.0.0.1:9000. Pascal has no tensor
    # cores and poor FP16, so CTranslate2 runs float32 here.
    virtualisation.oci-containers.containers.whisper-asr = {
      image = "onerahmet/openai-whisper-asr-webservice:latest-gpu";
      ports = ["127.0.0.1:${toString whisperPort}:9000"];
      environment = {
        ASR_ENGINE = "faster_whisper";
        ASR_MODEL = "medium";
        ASR_DEVICE = "cuda";
        TZ = "America/Los_Angeles";
      };
      volumes = ["/var/lib/whisper-asr/cache:/root/.cache"];
      extraOptions = ["--device=nvidia.com/gpu=all"];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/whisper-asr 0755 root root - -"
      "d /var/lib/whisper-asr/cache 0755 root root - -"
    ];
  };

  homepage = {config, ...}: {
    group = "Arr";
    name = "Bazarr";
    href = "http://${config.networking.hostName}:6767";
    icon = "bazarr";
    widget = {
      type = "bazarr";
      url = "http://localhost:6767";
      key = rylib.secretValue host "bazarr-api";
    };
  };
}
