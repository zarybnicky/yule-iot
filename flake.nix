{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-20.09-small;

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
      ];
    };

    nixosConfigurations.charlie = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.overlays = [ self.overlay ]; }
        (nixpkgs + "/nixos/modules/profiles/qemu-guest.nix")
        ({ pkgs, ... }: {

          system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          nix.package = pkgs.nixUnstable;
          nix.extraOptions = ''
            experimental-features = nix-command flakes
            gc-keep-outputs = true
            gc-keep-derivations = true
          '';
          nix.binaryCaches = [
            "https://cache.nixos.org"
            "https://zarybnicky-cache.cachix.org"
          ];
          nix.binaryCachePublicKeys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "zarybnicky-cache.cachix.org-1:TOV7XJZKtBg2N85nS2C0L1oPaN2M4vgEJj6LKrhGFWg="
          ];
          nix.trustedUsers = [ "root" "iot" ];

          boot.cleanTmpDir = true;
          boot.loader.grub.device = "/dev/sda";
          fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

          networking.firewall.allowPing = true;
          networking.firewall.allowedTCPPorts = [ 22 80 443 ];
          networking.hostName = "charlie";
          networking.domain = "z";

          system.autoUpgrade = {
            enable = true;
            flake = github:zarybnicky/yule-iot;
          };

          environment.systemPackages = [
            pkgs.git pkgs.cachix
          ];

          services.openssh.enable = true;
          services.openssh.permitRootLogin = "yes";
          # services.mysql = {
          #   enable = true;
          #   package = pkgs.mariadb;
          #   ensureDatabases = ["iot"];
          #   ensureUsers = [{
          #     name = "iot";
          #     ensurePermissions = { ".*" = "ALL PRIVILEGES"; };
          #   }];
          # };

          users.mutableUsers = false;
          users.users.iot = {
            isNormalUser = true;
            home = "/home/iot";
            extraGroups = [ "wheel" "networkmanager" ];
            openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBN7CIh8YtBQTzJO5g4+JWRwJgEvQqokwp1bwNwJRvxJMFM5x6el9sp5qWIIO7tNebk7y6sZtUJNn8i917m4JVvmu6ot5mmBC4PfqTEik1WR2U1ErIcvpzZoBdoRWie3bAVajM3a8MIg1MuqLsNHRI+d3lOq6aZO4eKROxouVDfzojIx+1TCF//pyIf6quhxxLzw1mFadcoGn4Xpv9rpftNKtU3ZuFTGUMtRD130zeOWLsbOz+I22o+cyZv+T6bN9CBYlQPmD2a2kdv/WjhrFwYm8GZGnZQUoVm6ipamen7+RyIULY3mMMaaQHFltMZnNl1XQezWqmOq0M9zvsqt5wXeXbsQJluG6RCHDd82qx1uNQZ/ZUpFhVK+d4kbKXtvob0eHuSG5HkJwS6F5njKKuAWZg4nM7+tkTNvHMvyFpnRurC0RuQe1ZE2mVDTUxgCNi5NuIi/eCkmB5lPu0B9sA4JgWrRj1MjasF9ljNGAW2VpfaJu6PgutYbIRsgqsBvXNimQD6Y5pPPstJF9ANH3CcEa08IS7D7v6RgHNNAtFBJVj5lu/3RT0Icjazcq16Wa+zTg+bkipXPh37lqnQrgYtupYOMGiwRQn9pPtT+OoBPqCNu8BwoUhyO+EcwUg3MboKmatYdPYYicpz0cWkCwikVDjlzTkltcRpMGntmd40Q== inuits@nixos"
            ];
          };
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDSEpOb1URHEE1JmN6XETlURLOhmy53d8CS22WixcqWisaNKluU5skD9oceFLatyWw85vFWwI6sT7RI+dk6RlBEpEKdzlwoW5wMhdjK+v6gdH1LFjEp/shEoNsu7oKSunzeNQ1ZY8holUmQ8lghGy+jkXX8ANXJNl5kVvhFU+22p8ivVibyO5gjfa6ZFzQvrt6ifq38qDYF5eqds/HkuSnc9tg8B6ilXkDo3FNneyoK9iVJ6l0M/sx0pZoWylFE8348k9LZMDLRN82uUTBsxlZqHFIJqf0UWq1OYInlExOgb12i3WTdFAqFrXz9fS9TIbxag7+Zd90vlAuatb1Sd4cr kuba.zarybnicky@post.cz"
          ];

        })
      ];
    };
  };
}
