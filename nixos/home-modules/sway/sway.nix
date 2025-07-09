{ config, pkgs, wayland, ... }:

{

  programs.waybar = {
    enable = true;

    settings = {
  mainBar = {
    layer = "top";
    position = "bottom";
    height = 30;
    modules-left = [ "sway/workspaces" "sway/mode" "wlr/taskbar" ];
    modules-right = [ "mpd" "clock" ];
    output = [
      "DP-1"
      "DP-2"
      "HDMI-A-1"
    ];
    "sway/workspaces" = {
      disable-scroll = true;
      all-outputs = true;
    };

    "clock" = {
      "format" = "{:%I:%M:%S }";
      "format-alt" = "{:%Y-%m-%d}";
    };

    "custom/hello-from-waybar" = {
      format = "hello {}";
      max-length = 40;
      interval = "once";
      exec = pkgs.writeShellScript "hello-from-waybar" ''
        echo "from within waybar"
      '';
    };
  };
};

    style = "
      * {
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgb(30,30,46);
        color: #AAB2BF;
      }

      #workspaces button {
      color: white;
      padding: 0 5px;
      }

    ";



  };



  

  wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      
      # Sway-specific Configuration
      config = {
        output."*" = {
          bg = "${./wallpaper.png} fill";
          

        };
      	modifier = "Mod4";
        terminal = "alacritty";
        menu = "wofi --show run";
        # Status bar(s)
        bars = [{
          command = "waybar";# You can change it if you want
        }];
        # Display device configuration
        output = {
          eDP-1 = {
            # Set HIDP scale (pixel integer scaling)
            
            scale = "1";
	      };
	    };
      };

      extraConfig = "
        output HDMI-A-1 resolution 2560x1440 position 0,0
        output DP-1 resolution 2560x1440 position 2560,0
        output DP-2 resolution 1920x1080 position 5120,200

        default_border pixel 0
        gaps inner 0
        gaps outer 0

        bindsym Mod4+g exec google-chrome-stable
        bindsym Mod4+m exec gnome-system-monitor 
        bindsym Mod4+c exec cider
        bindsym Mod4+t exec discord

        bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +3% 
        bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -3% 
        bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle 
        bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle 



      ";
  };
}

