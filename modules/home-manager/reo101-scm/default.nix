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
    # TODO: module options???
    name = "reo101";
    email = "pavel.atanasov2001@gmail.com";
    # NOTE: GPG
    # key = "675AA7EF13964ACB";
    # NOTE: YubiKey
    key = "7DA978E6383E5885";
  in {
    home.packages = with pkgs;
      builtins.concatLists [
        (optionals cfg.git.enable [
          # git
        ])
        (optionals cfg.jj.enable [
          jujutsu
          watchman
        ])
      ];

    programs.git = mkIf cfg.git.enable {
      enable = true;
      package = pkgs.gitFull;
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
          private-commits = "description(glob:'wip:*')";
        };
        signing = {
          backend = "gpg";
          # sign-all = true;
          # key = "675AA7EF13964ACB";
          # sign-all = config.programs.git.signing.signByDefault;
          # key = config.programs.git.signing.key;
          sign-all = false;
          inherit key;
        };
        core = {
          fsmonitor = "watchman";
          watchman = {
            register_snapshot_trigger = true;
          };
        };
        ui = {
          color = "always";
          # pager = "nvim";
          editor = "nvim";
          diff-editor = [
            "nvim"
            "-c"
            "DiffEditor $left $right $output"
          ];
        };
        # revsets = {
        #   log = "@ | bases | branches | curbranch::@ | @::nextbranch | downstream(@, branchesandheads)";
        # };
        # revset-aliases = {
        #   "bases" = "master";
        #   "downstream(x,y)" = "(x::y) & y";
        #   "branches" = "downstream(trunk(), bookmarks()) & mine()";
        #   "branchesandheads" = "branches | (heads(trunk()::) & mine())";
        #   "currbranch" = "latest(branches::@- & branches)";
        #   "nextbranch" = "roots(@:: & branchesandheads)";
        # };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
