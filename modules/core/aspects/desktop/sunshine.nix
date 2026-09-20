let
  rylib = import ../../_lib.nix;
in {
  # Sunshine, the host half of Moonlight game streaming
  # (github:LizardByte/Sunshine). Pair clients and add apps from the web UI on
  # https://localhost:47990; the stream itself follows the graphical session,
  # so the seat has to be logged in.
  ry.sunshine = {
    # The virtual gamepad/keyboard/mouse Sunshine creates for the client go
    # through /dev/uinput.
    includes = [(rylib.groups ["input" "uinput"])];

    nixos = {pkgs, ...}: {
      services.sunshine = {
        enable = true;
        openFirewall = true;

        # NVENC needs two things that nixpkgs does not give it by default.
        #
        # 1. cudaSupport. Every capture backend gates the nvenc path behind
        #    `#ifdef SUNSHINE_BUILD_CUDA` (wlgrab.cpp:276, kmsgrab.cpp:1247,
        #    pipewire.cpp:893); nixpkgs passes SUNSHINE_ENABLE_CUDA=OFF without
        #    it. Sunshine then asks for a CUDA frame, falls through to a plain
        #    software encode device and dies in sws_scale_frame -- logged as the
        #    very unhelpful "Couldn't scale frame: Invalid argument", after which
        #    it quietly settles on libx264 at ~20ms of host latency per frame.
        #    cudaPackages has to be passed too: it defaults to `{}`, so
        #    cudaSupport alone fails on cudaPackages.backendStdenv.
        #
        # 2. /run/opengl-driver/lib on the RUNPATH, so the dlopen of
        #    libnvidia-encode.so.1 resolves. (Symptom when it doesn't: "Cannot
        #    load libnvidia-encode.so.1", plus a bogus "minimum required driver
        #    is 570.0" -- ffmpeg's fallback text for any dlopen miss, not a real
        #    version check.) cudaSupport happens to cover this as well, via the
        #    autoAddDriverRunpath hook the CUDA setup hooks pull in; it is the
        #    reason no explicit addDriverRunpath is needed here. Note that
        #    LD_LIBRARY_PATH would not have worked: capSysAdmin below routes
        #    ExecStart through security.wrappers, and NixOS's wrapper.c unsets
        #    every name in glibc's UNSECURE_ENVVARS before exec.
        package = pkgs.sunshine.override {
          cudaSupport = true;
          inherit (pkgs) cudaPackages;
        };

        # Capture currently goes through wlgrab: niri does implement
        # zwlr_screencopy_manager_v1, so Sunshine's wayland backend works and
        # needs no privileges. CAP_SYS_ADMIN is kept only for the DRM/KMS
        # fallback, which is what's left if screencopy ever goes away (niri
        # still implements neither wlr-export-dmabuf, niri-wm/niri#2298, nor
        # NvFBC).
        capSysAdmin = true;

        # Don't start with the graphical session: this only drops the
        # graphical-session.target wantedBy, so the user unit is still there and
        # `systemctl --user start sunshine` brings it up when a stream is
        # actually wanted. It stays partOf graphical-session.target either way,
        # so it still goes down with the session.
        autoStart = false;

        # `settings` and `applications` are deliberately left unset: the nixpkgs
        # module only passes a config file once one of them is set, and from then
        # on the web UI can no longer save anything -- every app and every
        # resolution tweak would have to come back through here.
      };
    };
  };
}
