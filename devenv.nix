{
  pkgs,
  lib,
  config,
  ...
}: {
  packages = [pkgs.coreutils pkgs.sqlx-cli];
  dotenv.enable = true;
  # https://devenv.sh/languages/
  languages.rust.enable = true;
  services.postgres = {
    enable = true;

    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
    initialDatabases = [{name = "essensplan_dev";}];
    listen_addresses = "0.0.0.0";
    settings = {
      log_connections = true;
      log_statement = "all";
      logging_collector = true;
      log_disconnections = true;
    };
  };
}
