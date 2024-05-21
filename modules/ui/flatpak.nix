{
  nix-flatpak,
  pkgs,
  config,
  lib,
  ...
}:

# Flatpak support and options
let
  cfg = config.host.ui.flatpak;
in
with lib;
{
  options = {
    host.ui.flatpak.enable = mkEnableOption (mdDoc "Enables Flatpak");
  };

  config = mkIf cfg.enable {
    # Enable Flatpak
    services.flatpak = {
      enable = true;

      # Manage all Flatpak packages and remotes
      uninstallUnmanaged = true;

      # Enable daily automatic updates
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };

      # Add remote(s)
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];

      # Install base Flatpaks. For details, see https://github.com/gmodena/nix-flatpak
      packages = [
        "com.github.tchx84.Flatseal"
        "md.obsidian.Obsidian"
        "net.waterfox.waterfox"
        "org.keepassxc.KeePassXC"
      ];
    };

    # Workaround for getting Flatpak apps to use system fonts, icons, and cursors
    # For details (and source), see https://github.com/NixOS/nixpkgs/issues/119433#issuecomment-1767513263
    # NOTE: If fonts in Flatpaks appear incorrect (like squares), run this command to regenerate the font cache:
    #  flatpak list --columns=application | xargs -I %s -- flatpak run --command=fc-cache %s -f -v
    system.fsPackages = [ pkgs.bindfs ];
    fileSystems =
      let
        mkRoSymBind = path: {
          device = path;
          fsType = "fuse.bindfs";
          options = [
            "ro"
            "resolve-symlinks"
            "x-gvfs-hide"
          ];
        };
        aggregatedIcons = pkgs.buildEnv {
          name = "system-icons";
          paths = with pkgs; [
            #libsForQt5.breeze-qt5	# for plasma
            gnome.gnome-themes-extra
            papirus-icon-theme
            qogir-icon-theme
          ];
          pathsToLink = [ "/share/icons" ];
        };
        aggregatedFonts = pkgs.buildEnv {
          name = "system-fonts";
          paths = config.fonts.packages;
          pathsToLink = [ "/share/fonts" ];
        };
      in
      {
        "/usr/share/icons" = mkRoSymBind "${aggregatedIcons}/share/icons";
        "/usr/local/share/fonts" = mkRoSymBind "${aggregatedFonts}/share/fonts";
      };
  };
}
