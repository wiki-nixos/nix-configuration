{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Do not change this value! This tracks when NixOS was installed on your system.
  stateVersion = "24.11";
  hostName = "Dimaga";

  start-services = pkgs.writeShellScriptBin "start-services" (
    builtins.readFile ../Haven/start-haven.sh
  );

  services-root = "/storage/services";

  subdomains = [
    config.secrets.services.airsonic.url
    config.secrets.services.cache.url
    config.secrets.services.forgejo.url
    config.secrets.services.gremlin-lab.url
  ];

  namecheapCredentials = {
    "NAMECHEAP_API_USER_FILE" = "${pkgs.writeText "namecheap-api-user" ''
      ${config.secrets.networking.namecheap.api.user}
    ''}";
    "NAMECHEAP_API_KEY_FILE" = "${pkgs.writeText "namecheap-api-key" ''
      ${config.secrets.networking.namecheap.api.key}
    ''}";
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  system.stateVersion = stateVersion;
  networking.hostName = hostName;

  ###*** Configure your system below this line. ***###
  # Set your time zone.
  #   To see all available timezones, run `timedatectl list-timezones`.
  time.timeZone = "America/New_York";

  # Disable suspend
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Configure the system.
  aux.system = {
    # Enable to allow unfree (e.g. closed source) packages.
    # Some settings may override this (e.g. enabling Nvidia GPU support).
    # https://nixos.org/manual/nixpkgs/stable/#sec-allow-unfree
    allowUnfree = true;

    apps.tmux.enable = true;

    # Enable Secure Boot support.
    bootloader = {
      enable = true;
      secureboot.enable = true;
      tpm2.enable = true;
    };

    # Change the default text editor. Options are "emacs", "nano", or "vim".
    editor = "nano";

    # Enable GPU support.
    gpu = {
      intel.enable = true;
      nvidia = {
        enable = true;
        hybrid = {
          enable = true;
          busIDs.nvidia = "PCI:3:0:0";
          busIDs.intel = "PCI:0:2:0";
        };
      };
    };

    packages = [
      start-services
      pkgs.htop
    ];

    # Change how long old generations are kept for.
    retentionPeriod = "monthly";

    services = {
      acme = {
        enable = true;
        defaultEmail = config.secrets.users.aires.email;
        certs = {
          "${config.secrets.networking.primaryDomain}" = {
            dnsProvider = "namecheap";
            extraDomainNames = subdomains;
            webroot = null; # Required in order to prevent a failed assertion
            credentialFiles = namecheapCredentials;
          };
          "${config.secrets.networking.blogDomain}" = {
            dnsProvider = "namecheap";
            webroot = null; # Required in order to prevent a failed assertion
            credentialFiles = namecheapCredentials;
          };
        };
      };
      apcupsd = {
        enable = true;
        configText = builtins.readFile ../Haven/etc/apcupsd.conf;
      };
      airsonic = {
        enable = true;
        autostart = false;
        home = "${services-root}/airsonic-advanced";
        domain = config.secrets.networking.primaryDomain;
        url = config.secrets.services.airsonic.url;
      };
      autoUpgrade = {
        enable = false; # Don't update the system...
        pushUpdates = true; # ...but do push updates remotely.
        configDir = config.secrets.nixConfigFolder;
        onCalendar = "daily";
        user = config.users.users.aires.name;
      };
      boinc.enable = true;
      cache = {
        enable = false; # Disable for now
        secretKeyFile = "${services-root}/nix-cache/cache-priv-key.pem";
      };
      duplicacy-web = {
        enable = true;
        autostart = false;
        environment = "/storage/backups/settings/Haven";
      };
      forgejo = {
        enable = true;
        autostart = false;
        home = "${services-root}/forgejo";
        domain = config.secrets.networking.primaryDomain;
        url = config.secrets.services.forgejo.url;
        actions = {
          enable = true;
          token = config.secrets.services.forgejo.runner-token;
        };
      };
      msmtp.enable = true;
      nginx = {
        enable = true;
        autostart = false;
        virtualHosts = {
          "${config.secrets.networking.primaryDomain}" = {
            default = true;
            enableACME = true; # Enable Let's Encrypt
            locations."/" = {
              # Catchall vhost, will redirect users to Forgejo
              return = "301 https://${config.secrets.services.forgejo.url}";
            };
          };
          "${config.secrets.networking.blogDomain}" = {
            useACMEHost = config.secrets.networking.blogDomain;
            forceSSL = true;
            root = "${services-root}/nginx/sites/${config.secrets.networking.blogDomain}";
          };
          "${config.secrets.services.gremlin-lab.url}" = {
            useACMEHost = config.secrets.networking.primaryDomain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://${config.secrets.services.gremlin-lab.ip}";
              proxyWebsockets = true;
              extraConfig = "proxy_ssl_server_name on;";
            };
          };
        };
      };
      ssh = {
        enable = true;
        ports = [ config.secrets.hosts.haven.ssh.port ];
      };
      virtualization = {
        host = {
          enable = true;
          user = "aires";
          vmBuilds = {
            enable = true;
            cores = 3;
            ram = 3072;
          };
        };
      };
    };

    users.aires = {
      enable = true;
      services = {
        syncthing = {
          enable = true;
          autostart = false;
        };
      };
    };
  };
}
