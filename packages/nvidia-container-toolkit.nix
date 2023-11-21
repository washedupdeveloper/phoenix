{
  fetchFromGitHub,
  lib,
  buildGoModule,
}:
buildGoModule {
  name = "Nvidia Container Toolkit";
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nvidia-container-toolkit";
    rev = "v1.14.3";
    hash = lib.fakeSha256;
  };
  vendorSha256 = lib.fakeSha256;
  meta = {
    license = lib.licenses.asl20;
    maintainers = with maintainers; [];
  };
}
