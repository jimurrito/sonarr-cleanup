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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    test-vm.url = "github:jimurrito/nixos-test-vm";
  };
  #
  outputs =
    {
      self,
      nixpkgs,
      test-vm,
    }:
    let
      # Inject powershell.config.json into $PSHOME
      # Without this, powershell is verbose log a bunch of random crap when used in a systemd service.
      quietPowershell = pkgs.powershell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          echo '{"LogLevel":"Critical"}' > $out/share/powershell/powershell.config.json
        '';
      });
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
    in
    with lib;
    {
      #
      packages.${system}.default = pkgs.stdenv.mkDerivation {
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
          ${getExe quietPowershell} -NonInteractive -NoLogo -NoProfile -Command "$moduleDir/app.ps1" "\$@"
          EOF
          chmod +x "$out/bin/sonarr-cleanup"
        '';
      };
      #
      #
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          pkgsystem = pkgs.stdenv.hostPlatform.system;
          mainpackage = self.packages.${pkgsystem}.default;
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
            # Imports package and runs the install steps
            environment.systemPackages = [
              mainpackage
            ];
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
                path = [
                  quietPowershell
                ];
                serviceConfig = {
                  Type = "oneshot";
                  User = "sonarr-cleanup";
                  Group = "sonarr-cleanup";
                  ExecStart = ''
                    ${getExe mainpackage} -Url ${sonclu-nixops.url} -ApiKeyPath ${sonclu-nixops.keyPath}
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
