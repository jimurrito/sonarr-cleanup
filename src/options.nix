{ lib, ... }:
with lib;
{
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
}
