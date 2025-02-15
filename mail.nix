{
  lib,
  config,
  ...
}: let
  cfg = config.services.mailserver;
  transform_login_accounts = domain: input:
    builtins.listToAttrs (map (key: {
      name = key + "@" + domain;
      value = input.${key};
    }) (builtins.attrNames input));
in {
  options = {
    services.mailserver.enable = lib.mkEnableOption "Mail server";
    services.mailserver.domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain name of the mail server";
    };
    services.mailserver.loginAccounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            hashedPassword = lib.mkOption {
              type = lib.types.str;
            };

            hashedPasswordFile = with lib; mkOption {
              type = with types; nullOr str;
              default = null;
              defaultText = literalExpression "null";
              description = ''
                The full path to a file that contains the hash of the user's
                password. The file should contain exactly one line, which
                should be the password in an encrypted form that is suitable
                for the `chpasswd -e` command.
              '';
            };
          };
        }
      );

      default = {};
      description = "A list of all login accounts";
    };
  };
  config = lib.mkIf cfg.enable {
    mailserver = {
      enable = true;
      fqdn = "mail." + cfg.domain;
      domains = [cfg.domain];
      enableSubmissionSsl = false;

      loginAccounts = transform_login_accounts cfg.domain cfg.loginAccounts;

      certificateScheme = "acme-nginx";
    };
    security.acme.acceptTerms = true;
    security.acme.defaults.email = "security@" + cfg.domain;
  };
}
