{ lib, pkgs, config, ... }:

let
  cfg = config.reo101.scm;

  inherit (lib)
    mkEnableOption
    types
    mkIf
    optionals
    mkMerge;
in
{
  imports =
    [
    ];

  options =
    {
      reo101.scm = {
        git = {
          enable = mkEnableOption "reo101 git setup";
        };
        jj = {
          enable = mkEnableOption "reo101 jj setup";
        };
      };
    };

  config = let
    # TODO: agenix???
    name = "reo101";
    email = "pavel.atanasov2001@gmail.com";
    key = "675AA7EF13964ACB";
  in {
    home.packages = with pkgs;
      builtins.concatLists [
        (optionals cfg.git.enable [
          git
        ])
        (optionals cfg.jj.enable [
          jujutsu
        ])
      ];

    programs.git = mkIf cfg.git.enable {
      enable = true;
      userName = name;
      userEmail = email;
      signing = {
        signByDefault = true;
        inherit key;
      };
      lfs = {
        enable = true;
      };
      extraConfig = {
        init.defaultBranch = "master";
      };
    };


    programs.jujutsu = mkIf cfg.jj.enable {
      enable = true;
      package = pkgs.jujutsu;
      settings = {
        user = {
          # name = "reo101";
          # email = "pavel.atanasov2001@gmail.com";
          # name = config.programs.git.userName;
          # email = config.programs.git.userEmail;
          inherit name email;
        };
        git = {
          fetch = ["origin" "upstream"];
          push = "github";
        };
        signing = {
          backend = "gpg";
          # sign-all = true;
          # key = "675AA7EF13964ACB";
          # sign-all = config.programs.git.signing.signByDefault;
          # key = config.programs.git.signing.key;
          sign-all = true;
          inherit key;
        };
        core.fsmonitor = "watchman";
        ui = {
          color = "always";
          # pager = "nvim";
          editor = "nvim";
        };
        revsets = {
          log = "@ | bases | branches | curbranch::@ | @::nextbranch | downstream(@, branchesandheads)";
        };
        revset-aliases = {
          "bases" = "dev";
          "downstream(x,y)" = "(x::y) & y";
          "branches" = "downstream(trunk(), branches()) & mine()";
          "branchesandheads" = "branches | (heads(trunk()::) & mine())";
          "curbranch" = "latest(branches::@- & branches)";
          "nextbranch" = "roots(@:: & branchesandheads)";
        };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
