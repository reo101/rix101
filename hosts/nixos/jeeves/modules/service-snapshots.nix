{
  inputs,
  config,
  lib,
  ...
}:
let
  knot = config.services.tangled.knot-rs;
  spindle = config.services.tangled.spindle;
in
{
  imports = [ inputs.self.nixosModules.service-snapshots ];

  rix101.serviceSnapshots.groups.atproto = {
    units = [
      "tranquil-pds.service"
    ]
    ++ lib.optional knot.enable "knot-rs.service"
    ++ lib.optional spindle.enable "spindle.service";
    databases = [ "tranquil-pds" ];
    subvolumes = {
      "/data/pds" = {
        user = "tranquil-pds";
        group = "tranquil-pds";
      };
    }
    // lib.optionalAttrs knot.enable {
      ${knot.stateDir} = {
        inherit (knot) user group;
        mode = "0750";
      };
    }
    // lib.optionalAttrs spindle.enable {
      "/var/lib/spindle" = { };
    };
    recoveryFiles = {
      "pds.environment.age" = config.age.secrets."pds.environment".rekeyFile;
      "pds.jwt-secret.age" = config.age.secrets."pds.jwt-secret".rekeyFile;
      "pds.dpop-secret.age" = config.age.secrets."pds.dpop-secret".rekeyFile;
      "pds.master-key.age" = config.age.secrets."pds.master-key".rekeyFile;
    }
    // lib.optionalAttrs knot.enable {
      "tangled.master-key.age" = config.age.secrets."tangled.master-key".rekeyFile;
    };
  };
}
