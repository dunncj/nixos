{ pkgs, ... }:

let
  edidBase64 = "AP///////wAx2AAAAAAAAAAkAQOARid4Cu6Ro1RMmSYPUFQAAAABAQEBAQEBAQEBAQEBAQEBal4AoKCgKVAwIDUAuYghAAAaUNAAoPBwPoAwIDUAuYghAAAaAjqAGHE4LUBYLEUAuYghAAAeAAAA/ABWaXJ0dWFsCiAgICAgAGE=";

  virtualEdid = pkgs.runCommand "virtual-1080p-edid" { } ''
    mkdir -p "$out"
    printf '%s' '${edidBase64}' | base64 -d > "$out/edid.bin"
    [ "$(stat -c%s "$out/edid.bin")" = "128" ] || { echo "bad EDID size"; exit 1; }
  '';

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
