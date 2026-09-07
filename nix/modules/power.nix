# This box is a headless server (Sunshine/Moonlight host, k3s, Minecraft).
# Suspending takes the whole machine off the network until it is physically
# woken, so nothing here is allowed to sleep the system.
{ ... }:

{
  # Hard block: masking the sleep targets makes suspend/hibernate impossible,
  # whatever asks for it (PowerDevil, logind, `systemctl suspend`, an app).
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Belt and braces: logind should not even try to sleep on idle or on the
  # suspend/hibernate keys.
  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  # PowerDevil's AC profile defaults to "suspend after 15 minutes idle".
  # System-wide default; /etc/xdg is on XDG_CONFIG_DIRS for the session.
  #
  # Turning the display off is just as damaging here: it disables the DRM
  # connector, which kills Sunshine's KMS capture and makes Moonlight fail
  # with 503 until something wakes the display again.
  #
  # The *WhenIdle booleans are the real switches for each action (verified
  # against the key names in libpowerdevilcore.so) - setting the matching
  # *IdleTimeoutSec keys to -1 does NOT disable the action.
  #
  # But those booleans only gate the UNLOCKED idle path. Once the session
  # locks, PowerDevil switches to TurnOffDisplayIdleTimeoutWhenLockedSec
  # (short default) and blanks the display regardless, so that needs pinning
  # too.
  environment.etc."xdg/powerdevilrc".text = ''
    [AC]
    AutoSuspendWhenIdle=false
    DimDisplayWhenIdle=false
    TurnOffDisplayWhenIdle=false
    TurnOffDisplayIdleTimeoutWhenLockedSec=86400
  '';

  # And stop it locking in the first place: nobody is sat at this machine, and
  # a locked session both blanks the display (above) and greets Moonlight with
  # a lock screen. Autologin is already on, so the lock adds no protection.
  environment.etc."xdg/kscreenlockerrc".text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';
}
