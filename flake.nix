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
    # can not use espresso as it will cause a recursive error for users who use sonarr-cleanup via espresso
    qpwsh = {
      url = "git+https://forgejo.immerhouse.com/jimurrito/quiet-powershell";
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
      # package function that allows for arch specific pkgs to be provided
      # mkPackage = pkgs: pkgs.sonarr-cleanup;
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
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          sonclu-nixops = config.services.sonarr-cleanup;
        in
        with lib;
        {
          # Options for services overlay
          options.services.sonarr-cleanup = {
            enable = mkEnableOption "Sonarr Cleanup service";
            url = mkOption {
              type = types.str;
              default = "http://127.0.0.1:8989";
              description = "URL to the sonarr instance. Must include protocol (http/s)";
            };
            keyPath = mkOption {
              type = types.str;
              default = "/root/sonarr-key";
              description = "API key for the target Sonarr Instance";
            };
            interval = mkOption {
              type = types.str;
              default = "hourly";
              description = "How often to run cleanup. Accepts any systemd calendar expression.";
            };
          };
          #
          # config to be implemented via the `options`
          config = mkIf sonclu-nixops.enable {
            # Imports the overlay to put sonarr-cleanup in pkgs
            nixpkgs.overlays = [ self.overlays.default ];
            # rootless identity
            users = {
              groups.sonarr-cleanup = { };
              users.sonarr-cleanup = {
                enable = true;
                group = "sonarr-cleanup";
                isSystemUser = true;
              };
            };
            # systemd service
            systemd = {
              # systemd service
              services.sonarr-cleanup = {
                enable = true;
                description = "Sonarr Cleanup service";
                restartIfChanged = true;
                serviceConfig = {
                  Type = "oneshot";
                  User = "sonarr-cleanup";
                  Group = "sonarr-cleanup";
                  ExecStart = ''
                    ${getExe pkgs.sonarr-cleanup} -Url ${sonclu-nixops.url} -ApiKeyPath ${sonclu-nixops.keyPath}
                  '';
                };
              };
              # timer for service triggering
              timers.sonarr-cleanup = {
                enable = true;
                description = "Triggers sonarr-cleanup service";
                wantedBy = [ "timers.target" ];
                timerConfig.OnCalendar = sonclu-nixops.interval;
              };
            };
          };
        };
      #
      #
      #
      # TestVM
      nixosConfigurations =
        let
          testConfig =
            { ... }:
            {
              services.sonarr-cleanup = {
                enable = true;
                url = "https://sonarr.immerhouse.com";
                interval = "hourly";
                keyPath = "/etc/sonarr-key";
              };
            };
        in
        {
          test-vm = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              test-vm.baselineConfig
              # test config
              self.nixosModules.default
              testConfig
            ];
          };
        };
    };
}
