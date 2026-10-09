{ lib, ... }:

{
  options = {
    configurationType = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Configuration generator type.";
    };
  };
}
