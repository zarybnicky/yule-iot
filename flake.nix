{
  outputs = { self, nixpkgs }: let
    inherit (nixpkgs.lib) flip mapAttrs mapAttrsToList;
    inherit (pkgs.nix-gitignore) gitignoreSourcePure gitignoreSource;

    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
    pythonEnv = pkgs.python38.withPackages (ps: [
      ps.pika
    ]);
    getSrc = dir: gitignoreSourcePure [./.gitignore] dir;

  in {
    overlay = final: prev: {
      python38 = prev.python38.override {
        packageOverrides = pyself: pysuper: {
          pyo = pyself.buildPythonPackage rec {
            pname = "pyo";
            version = "1.0.3";
            name = "${pname}-${version}";
            src = pyself.fetchPypi {
              inherit pname version;
              sha256 = "8NGHp446ufECdYU6IraggJSu7U4MKt7oaXc0Nzqo3R8=";
            };
            doCheck = false;
            buildInputs = [
              final.fftw.dev
              final.portaudio
              final.portmidi
              final.liblo
              final.libsndfile.dev
            ];
          };
        };
      };
    };

    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = [ pythonEnv ];
    };

    nixosConfigurations.charlie = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        { nixpkgs.overlays = [ self.overlay ]; }
        { nixpkgs.config.allowUnfree = true; }
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

          time.timeZone = "Europe/Prague";
          i18n.defaultLocale = "en_US.UTF-8";
          console.font = "Lat2-Terminus16";
          console.keyMap = "cz";

          boot.cleanTmpDir = true;
          boot.loader.grub.device = "/dev/sda";
          fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

          networking.firewall.allowPing = true;
          networking.firewall.allowedTCPPorts = [ 22 80 443 1883 5672 ];
          networking.hostName = "charlie";
          networking.domain = "z";

          system.autoUpgrade = {
            enable = true;
            flake = github:zarybnicky/yule-iot/master;
          };

          environment.systemPackages = with pkgs; [
            coreutils diffutils findutils binutils file htop silver-searcher ripgrep
            git cachix rabbitmq-server mosquitto direnv nix-direnv
            pythonEnv
          ];
          environment.pathsToLink = [ "/share/nix-direnv" ];

          services.fail2ban.enable = true;
          security.sudo.wheelNeedsPassword = false;
          services.openssh.enable = true;
          services.openssh.permitRootLogin = "yes";

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

        ({ pkgs, config, ... }: {
          services.nginx = {
            enable = true;
            enableReload = true;
            recommendedGzipSettings = true;
            recommendedOptimisation = true;
            recommendedProxySettings = true;
            statusPage = true;
            virtualHosts."iot.zarybnicky.com" = {
              enableACME = true;
              forceSSL = true;
              locations."/" = {
                root = getSrc ./web;
                index = "index.html";
                extraConfig = ''
                  rewrite ^/(css/.*)$ /rabbitmq/$1 last;
                  rewrite ^/(js/.*)$ /rabbitmq/$1 last;
                  rewrite ^/(api/.*)$ /rabbitmq/$1 last;
                  rewrite ^/img/rabbitmqlogo.svg$ /rabbitmq/img/rabbitmqlogo.svg last;
                  rewrite ^/favicon.ico$ /rabbitmq/favicon.ico last;
                '';
              };
              locations."/grafana" = {
                proxyPass = "http://127.0.0.1:3000";
                proxyWebsockets = true;
              };
              locations."/prometheus" = {
                proxyPass = "http://127.0.0.1:9090";
                proxyWebsockets = true;
              };
              locations."/rabbitmq" = {
                proxyPass = "http://127.0.0.1:15672";
                proxyWebsockets = true;
              };
              locations."/kibana" = {
                proxyPass = "http://127.0.0.1:5601";
                proxyWebsockets = true;
              };
            };
          };
          security.acme.acceptTerms = true;
          security.acme.email = "jakub@zarybnicky.com";

          services.elasticsearch = {
            enable = true;
            extraJavaOptions = [ "-Xms128m" ];
          };
          services.kibana = {
            enable = true;
            extraConf = {
              "server.basePath" = "/kibana";
              "server.rewriteBasePath" = true;
            };
          };
          services.logstash = {
            enable = true;
            dataDir = "/var/lib/logstash";
            inputConfig = ''
              rabbitmq {
                host => "127.0.0.1"
                queue => "logstash"
                exchange => "amq.topic"
                key => "#"
                durable => true
              }
            '';
            outputConfig = "elasticsearch { }";
          };
          systemd.services.logstash.environment.ES_JAVA_OPTS = "-Xms128m";

          services.grafana = {
            enable = true;
            domain = "iot.zarybnicky.com";
            rootUrl = "https://iot.zarybnicky.com/grafana/";
            auth.anonymous.enable = true;
            auth.anonymous.org_role = "Editor";
          };
          systemd.services.grafana.environment.GF_SERVER_SERVE_FROM_SUB_PATH = "true";

          services.prometheus = {
            enable = true;
            webExternalUrl = "https://iot.zarybnicky.com/prometheus";
            globalConfig.scrape_interval = "15s";
            rules = [];
            scrapeConfigs = [
              {
                job_name = "node";
                static_configs = [{
                  targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
                }];
              } {
                job_name = "nginx";
                static_configs = [{
                  targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
                }];
              } {
                job_name = "rabbitmq";
                static_configs = [{
                  targets = [ "127.0.0.1:15692" ];
                }];
              }
            ];
          };
          services.prometheus.exporters.nginx = {
            enable = true;
          };
          services.prometheus.exporters.node = {
            enable = true;
            enabledCollectors = [
              "logind"
              "systemd"
            ];
            disabledCollectors = [
              "textfile"
            ];
          };

          services.rabbitmq = {
            enable = true;
            listenAddress = "0.0.0.0";
            plugins = [ "rabbitmq_mqtt" "rabbitmq_management" "rabbitmq_prometheus" ];
            configItems = {
              "management.path_prefix" = "/rabbitmq";
              "loopback_users" = "none";
              "mqtt.allow_anonymous" = "true";
              "mqtt.default_user" = "guest";
              "mqtt.default_pass" = "guest";
            };
          };

          services.loki = {
            enable = true;
            configFile = pkgs.writeText "loki.yaml" ''
              auth_enabled: false
              server:
                http_listen_port: 3100
              ingester:
                lifecycler:
                  address: 0.0.0.0
                  ring:
                    kvstore:
                      store: inmemory
                    replication_factor: 1
                  final_sleep: 0s
                chunk_idle_period: 1h
                max_chunk_age: 1h
                chunk_target_size: 1048576000
                chunk_retain_period: 30s
                max_transfer_retries: 0
              schema_config:
                configs:
                  - from: 2020-12-24
                    store: boltdb-shipper
                    object_store: filesystem
                    schema: v11
                    index:
                      prefix: index_
                      period: 24h
              storage_config:
                boltdb_shipper:
                  active_index_directory: /var/lib/loki/boltdb-shipper-active
                  cache_location: /var/lib/loki/boltdb-shipper-cache
                  cache_ttl: 24h
                  shared_store: filesystem
                filesystem:
                  directory: /var/lib/loki/chunks
              limits_config:
                reject_old_samples: true
                reject_old_samples_max_age: 168h
              chunk_store_config:
                max_look_back_period: 0s
              table_manager:
                retention_deletes_enabled: false
                retention_period: 0s
            '';
          };
          systemd.services.promtail = let
            promTail = pkgs.writeText "promtail.yaml" ''
              server:
                http_listen_port: 28183
                grpc_listen_port: 0
              positions:
                filename: /tmp/positions.yaml
              clients:
                - url: http://127.0.0.1:3100/loki/api/v1/push
              scrape_configs:
                - job_name: journal
                  journal:
                    max_age: 12h
                    labels:
                      job: systemd-journal
                      host: iot
                  relabel_configs:
                    - source_labels: ['__journal__systemd_unit']
                      target_label: 'unit'
            '';
          in {
            description = "Promtail service for Loki";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.grafana-loki}/bin/promtail --config.file ${promTail}";
            };
          };
        })
      ];
    };
  };
}
