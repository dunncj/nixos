{ ... }:

{
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  environment.etc."xdg/powerdevilrc".text = ''
    [AC]
    AutoSuspendWhenIdle=false
    DimDisplayWhenIdle=false
    TurnOffDisplayWhenIdle=false
    TurnOffDisplayIdleTimeoutWhenLockedSec=86400
  '';

  environment.etc."xdg/kscreenlockerrc".text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';
}
