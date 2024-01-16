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
  };
}
