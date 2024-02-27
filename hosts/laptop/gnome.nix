{pkgs, ...}: {
  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  services.xserver.desktopManager.gnome.enable = true;
  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];
  environment.systemPackages = with pkgs; [gnomeExtensions.appindicator];
  environment.gnome.excludePackages =
    (with pkgs; [gnome-photos gnome-connections gnome-tour])
    ++ (with pkgs.gnome; [
      # baobab # disk usage analyzer
      # simple-scan # document scanner
      # evince # document viewer
      # seahorse # password manager
      # gnome-calendar
      # gnome-clocks
      # gnome-font-viewer
      # gnome-logs
      # gnome-screenshot
      # gnome-system-monitor
      # gnome-disk-utility
      cheese # photo booth
      eog # image viewer
      epiphany # web browser
      gedit # text editor
      totem # video player
      yelp # help viewer
      file-roller # archive manager
      geary # email client
      gnome-calculator
      gnome-characters
      gnome-contacts
      gnome-maps
      gnome-music
      gnome-weather
    ]);
}
