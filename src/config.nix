{
  #self,
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
  #
  # config to be implemented via the `options`
  config = mkIf sonclu-nixops.enable {
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
}
