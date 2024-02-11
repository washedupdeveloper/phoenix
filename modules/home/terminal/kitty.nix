{pkgs, ...}: {
  home.packages = with pkgs; [kitty];

  programs.kitty = {
    enable = true;
    theme = "Monokai Pro";
    # font = {
    #   name = "Meslo";
    #   # package = nerdfonts.override {
    #   #   fonts = [
    #   #     "Meslo"
    #   #   ];
    #   # };
    # };
  };
}
