# Enables AMD GPU support.
{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.aux.system.gpu.amd;
in
{
  options = {
    aux.system.gpu.amd.enable = lib.mkEnableOption (lib.mdDoc "Enables AMD GPU support.");
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];
    services.xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
    };

    hardware.graphics = {
      extraPackages = [ pkgs.amdvlk ];
      # 32-bit application compatibility
      enable32Bit = true;
      extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];
    };
  };
}
