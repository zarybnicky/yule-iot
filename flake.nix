{
  outputs = { self, nixpkgs }: let
    inherit (nixpkgs.lib) flip mapAttrs mapAttrsToList;
    inherit (pkgs.nix-gitignore) gitignoreSourcePure gitignoreSource;

    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
    getSrc = dir: gitignoreSourcePure [./.gitignore] dir;

  in {
    overlay = final: prev: {
      test = pkgs.writeText "config.yaml" ''
        ...
      '';
    };

    packages.x86_64-linux = {
      inherit (pkgs) test;
    };

    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = [
        pkgs.cachix
      ];
    };

    nixosConfigurations.container = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModule
        { nixpkgs.overlays = [ self.overlay ]; }
        ({ pkgs, ... }: {
          boot.isContainer = true;
          system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          networking.useDHCP = false;
          networking.firewall.allowedTCPPorts = [ 80 3000 3306 ];
          services.mysql = {
            enable = true;
            package = pkgs.mariadb;
            ensureDatabases = ["iot"];
            ensureUsers = [{
              name = "iot";
              ensurePermissions = { ".*" = "ALL PRIVILEGES"; };
            }];
          };
        })
      ];
    };

    nixosModule = { config, lib, pkgs, ... }: let
      cfg = config.profile.iot;
    in {
      options.profile.iot.enable = lib.mkEnableOption "IoT profile";

      config = lib.mkIf cfg.enable {
        users.users.iot = {
          name = "iot";
          group = "iot";
          home = "/home/iot";
          createHome = true;
          useDefaultShell = true;
          isSystemUser = true;
        };
        users.groups."iot" = {
          name = "iot";
        };

        environment.systemPackages = [
        ];

        services.nginx = {
          enable = true;
          enableReload = true;
          recommendedGzipSettings = true;
          recommendedOptimisation = true;
          recommendedProxySettings = true;
        };

        # systemd.services.worker = {
        #   description = "... worker service";
        #   environment.CONFIG = cfgFile;
        #   serviceConfig = {
        #     Type = "simple";
        #     ExecStart = "${pkgs.api}/bin/...";
        #   };
        # };
        # systemd.timers.worker = {
        #   description = "... worker service timer";
        #   wantedBy = ["multi-user.service"];
        #   timerConfig = {
        #     Unit = "worker.service";
        #     OnBootSec = "10min";
        #     OnUnitActiveSec = "70min";
        #   };
        # };

      };
    };
  };
}
