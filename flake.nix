/*
  Example config

  services.sonarr-cleanup = {
    enable = true;
    interval = "hourly";
    keyPath = config.age.secrets.sonarr_key.path;
  };
*/
{
  description = "Sonarr-Cleanup script and service";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    test-vm = {
      url = "github:jimurrito/nixos-test-vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # can not use espresso as it will cause a recursive error for users who use this app via espresso
    qpwsh = {
      url = "github:jimurrito/quiet-powershell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  #
  outputs =
    {
      self,
      nixpkgs,
      test-vm,
      qpwsh,
    }:
    let
      #
      lib = nixpkgs.lib;
      # Supported Architectures
      archs = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # multi arch packager
      packager = sys: {
        ${sys}.default =
          let
            pkgs = import nixpkgs {
              system = sys;
              overlays = [ qpwsh.overlays.default ];
            };
          in
          with lib;
          pkgs.stdenv.mkDerivation {
            pname = "sonarr-cleanup";
            meta.mainProgram = "sonarr-cleanup";
            version = "0.1.0";
            src = ./.;
            dontBuild = true;
            #
            installPhase = ''
              moduleDir="$out/module"
              mkdir -p "$moduleDir"
              cp app.ps1 "$moduleDir/"
              mkdir -p "$out/bin"
              cat > "$out/bin/sonarr-cleanup" << EOF
              #!/usr/bin/env bash
              ${getExe pkgs.quietPowershell} -NonInteractive -NoLogo -NoProfile -Command "$moduleDir/app.ps1" "\$@"
              EOF
              chmod +x "$out/bin/sonarr-cleanup"
            '';
          };
      };
      #
    in
    {
      #
      # Builds packages for each arch provided
      # (') is required so foldl will be strict and not lazy
      packages = builtins.foldl' (acc: x: acc // x) { } (map packager archs);
      #
      # Nixpkgs overlay for the package(s)
      overlays.default = final: prev: {
        sonarr-cleanup = self.packages.${final.system}.default;
      };
      #
      # Default option to import package into the env
      # and import service options
      nixosModules.default.imports = [
        ./src/options.nix
        ./src/config.nix
        { nixpkgs.overlays = [ self.overlays.default ]; }
      ];
      #
      #
      #
      # TestVM
      nixosConfigurations = {
        test-vm = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            (import test-vm.baselineConfig { })
            self.nixosModules.default
            # test config
            {
              services.sonarr-cleanup = {
                enable = true;
                url = "https://sonarr.immerhouse.com";
                interval = "hourly";
                keyPath = "/etc/sonarr-key";
              };
            }
            #
          ];
        };
      };
    };
}
