{pkgs, ...}: {
  environment.systemPackages = with pkgs; [k3s];

  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      # "--kubelet-arg=v=4" # Optionally add additional args to k3s
    ];
  };

  networking = {
    firewall = {
      enable = true;
      allowedTCPPorts = [6443];
      allowedUDPPorts = [];
    };
  };

  #TODO: setup the default k3s config yaml file.
  #   environment.etc = {
  #     rancher.k3s.config.yaml = ''

  #     '';

  #     # The UNIX file mode bits
  #     mode = "0440";
  #   };
}
