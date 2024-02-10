{
  pkgs,
  username,
  ...
}: {
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = username;
    desktopManager.gnome.enable = true;
  };

  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];
  environment.systemPackages = with pkgs; [microsoft-edge-stable gnomeExtensions.appindicator];
  environment.gnome.excludePackages =
    (with pkgs; [gnome-photos gnome-connections gnome-tour])
    ++ (with pkgs.gnome; [
      # baobab # disk usage analyzer
      cheese # photo booth
      eog # image viewer
      epiphany # web browser
      gedit # text editor
      # simple-scan # document scanner
      totem # video player
      yelp # help viewer
      # evince # document viewer
      file-roller # archive manager
      # geary # email client
      # seahorse # password manager
      gnome-calculator
      gnome-calendar
      gnome-characters
      # gnome-clocks
      gnome-contacts
      # gnome-font-viewer
      # gnome-logs
      gnome-maps
      gnome-music
      # gnome-screenshot
      # gnome-system-monitor
      gnome-weather
      # gnome-disk-utility
    ]);
}
