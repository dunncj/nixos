{ pkgs, ... }:

let
  # This box is headless: every DRM connector reads "disconnected", so KWin has
  # no real output and Sunshine's KMS grab enumerates an empty monitor list
  # ("Unable to initialize capture method" -> no encoder -> HTTP 503 to Moonlight).
  #
  # Fix: hand the dGPU's DP-1 a synthetic EDID and force the connector on, which
  # gives KWin a CRTC to render into and Sunshine a monitor to capture.
  #
  # A `video=DP-1:1920x1080@60D` kernel param would also work, but it cannot be
  # verified without a reboot and synthesizes its own mode list; this does exactly
  # what was tested live on the running system.
  #
  # 128-byte EDID 1.3, name "Virtual". EDID 1.3 has exactly four descriptor slots
  # and the first detailed timing is the PREFERRED one, so the order below is what
  # KWin boots into:
  #
  #   1. 2560x1440@60  CVT-RB  241.70 MHz  <- preferred
  #   2. 3840x2160@60  CVT-RB  533.28 MHz
  #   3. 1920x1080@60  CEA     148.50 MHz
  #   4. monitor name "Virtual"
  #
  # 1440p is preferred rather than 4K deliberately: the desktop mode is also what
  # games render at, and an RX 7600 drives 1440p60 far more comfortably than 4K60.
  # Moonlight can still request 4K; switch the desktop with
  #   kscreen-doctor output.DP-1.mode.3840x2160@60
  #
  # 4K uses the CVT reduced-blanking timing (533.28 MHz) rather than the CEA one
  # (594 MHz) because the connector is force-enabled with no sink to link-train
  # against, so the lower pixel clock is likelier to survive mode validation.
  #
  # There is no range-limits (0xFD) descriptor because the feature byte leaves the
  # continuous-frequency bit clear, which frees that fourth slot for a third mode.
  #
  # Physical size is declared 697x392 mm (~31.5"). That is a lie, but a deliberate
  # one: it puts 4K at ~140 DPI so Plasma does not auto-select 2x scaling, which
  # would render the desktop at an effective 1080p and waste the extra pixels.
  #
  # Regenerate with: perl modules/sunshine-edid.pl | base64 -w0
  edidBase64 = "AP///////wAx2AAAAAAAAAAkAQOARid4Cu6Ro1RMmSYPUFQAAAABAQEBAQEBAQEBAQEBAQEBal4AoKCgKVAwIDUAuYghAAAaUNAAoPBwPoAwIDUAuYghAAAaAjqAGHE4LUBYLEUAuYghAAAeAAAA/ABWaXJ0dWFsCiAgICAgAGE=";

  virtualEdid = pkgs.runCommand "virtual-1080p-edid" { } ''
    mkdir -p "$out"
    printf '%s' '${edidBase64}' | base64 -d > "$out/edid.bin"
    [ "$(stat -c%s "$out/edid.bin")" = "128" ] || { echo "bad EDID size"; exit 1; }
  '';

  # dGPU (Radeon RX 7600). PCI address is stable; card0/card1 numbering is not.
  gpuPci = "0000:03:00.0";
  connector = "DP-1";
in
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  systemd.services.sunshine-virtual-display = {
    description = "Force a virtual 1080p display so headless Sunshine has something to capture";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    after = [ "sys-kernel-debug.mount" ];
    requires = [ "sys-kernel-debug.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.gnugrep
    ];
    script = ''
      set -eu

      drm=/sys/bus/pci/devices/${gpuPci}/drm

      # amdgpu can bind late; wait for the card node to appear.
      cardpath=""
      for _ in $(seq 1 50); do
        cardpath=$(ls -d "$drm"/card* 2>/dev/null | head -n1 || true)
        [ -n "$cardpath" ] && break
        sleep 0.2
      done
      if [ -z "$cardpath" ]; then
        echo "no DRM card for ${gpuPci}; nothing to do"
        exit 0
      fi

      conn=/sys/class/drm/$(basename "$cardpath")-${connector}
      if [ ! -e "$conn/status" ]; then
        echo "connector $conn not present; nothing to do"
        exit 0
      fi

      # A real monitor takes priority - never override actual hardware. But once
      # this unit has run, our own forced connector ALSO reads "connected", so a
      # bare status check cannot tell the two apart and would make every later
      # rebuild a silent no-op. Distinguish by monitor name: only the synthetic
      # EDID carries "Virtual" in its 0xFC descriptor.
      ours=false
      if grep -qa Virtual "$conn/edid" 2>/dev/null; then
        ours=true
      fi

      if [ "$(cat "$conn/status")" = "connected" ] && [ "$ours" != true ]; then
        echo "${connector} has a real monitor attached; leaving it alone"
        exit 0
      fi

      override=/sys/kernel/debug/dri/${gpuPci}/${connector}/edid_override
      if [ -w "$override" ]; then
        cat ${virtualEdid}/edid.bin > "$override"
      else
        echo "warning: $override not writable, forcing without EDID" >&2
      fi

      # The override is only consulted when the connector is probed, so a
      # connector we already forced on a previous run has to be released first or
      # it keeps serving the stale mode list. "detect" resets force to
      # unspecified (with no sink attached that drops it to disconnected);
      # "on" then re-forces and re-probes, picking up the new EDID.
      if [ "$ours" = true ]; then
        echo detect > "$conn/status" || true
      fi

      # Writing "on" both sets connector->force and triggers a re-probe.
      echo on > "$conn/status"

      # Nudge KWin if it is already running (no-op before display-manager starts).
      udevadm trigger --subsystem-match=drm --action=change || true

      echo "forced $conn on: status=$(cat "$conn/status") modes=$(tr '\n' ' ' < "$conn/modes")"
    '';
  };
}
