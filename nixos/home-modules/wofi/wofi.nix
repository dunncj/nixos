{ config, pkgs, wayland, ... }:


let 

  css = "
window {
  margin: 5px;
  background-color: rgb(30, 30, 46);
  border-radius: 10px;
}

#input {
  margin: 5px;
  background-color: rgb(30, 30, 46);
  color: white;
}

#inner-box {
  margin: 5px;
  background-color: rgb(30, 30, 46);
}

#outer-box {
  margin: 5px;
  background-color: rgb(30, 30, 46);
}

#scroll {
  margin: 5px;
  background-color: rgb(30, 30, 46);
}

#entry {
  
}

#text {
  margin: 5px;
  color: white;
}
";
  
in
{
  programs.wofi = {
    enable = true;
    settings = {
      display-drun = "Applications:";
      display-window = "Windows:";
      drun-display-format = "{name}";
      font = "JetBrainsMono Nerd Font Medium 10";
    };

    style = css;



  

  };

}

