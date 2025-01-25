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
          nvim = mkEnableOption "Integration with `hunk.nvim` and `jj-diffconflicts`" // {
            default = true;
          };
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
          gh
        ])
        (optionals cfg.jj.enable [
          # jujutsu
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
          push = "origin";
          private-commits = "description(glob:'wip:*')";
          push-bookmark-prefix = "reo101/";
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
        } // mkIf cfg.jj.nvim {
          # pager = "nvim";
          editor = "nvim -b";
          diff-editor = [
            "nvim"
            "-c"
            "DiffEditor $left $right $output"
          ];
        };
        merge-tools = {
          diffconflicts = mkIf cfg.jj.nvim {
            program = "nvim";
            merge-args = [
              "-c" "let g:jj_diffconflicts_marker_length=$marker_length"
              "-c" "JJDiffConflicts!" "$output" "$base" "$left" "$right"
            ];
            # NOTE: no history view
            # merge-args = [
            #   "-c" "JJDiffConflicts!" "$output"
            # ];
          };
        };
        revset-aliases = {
          "stragglers" = "(visible_heads() & mine()) ~ trunk()";
          "bases" = "master | main";
          "downstream(x,y)" = "(x::y) & y";
          "branches" = "downstream(trunk(), bookmarks()) & mine()";
          "branchesandheads" = "branches | (heads(trunk()::) & mine())";
          "currbranch" = "latest(branches::@- & branches)";
          "nextbranch" = "roots(@:: & branchesandheads)";
        };
        aliases = {
          "dragmain" = ["bookmark" "set" "main" "-r" "@-"];
          "sync" = ["git" "fetch" "--all-remotes"];
          "evolve" = ["rebase" "--skip-emptied" "-d" "trunk()"];
          "pullup" = ["evolve" "-s" "all:stragglers"];

          "xl" = ["log" "-r" "all()"];
          "pl" = ["obslog" "-p"];

          # "cl" = ["git" "push" "-c" "@-"];
          # "push" = ["git" "push" "--all"];

          "configure" = ["config" "edit" "--repo"];

          ".." = ["edit" "-r" "@-"];
          ",," = ["edit" "-r" "@+"];
        };
        template-aliases = {
          "format_timestamp(ts)" = ''
            if(
              ts.after("2 weeks ago"),
              ts.ago(),
              ts.format("%b %d, %Y %H:%M"),
            )
          '';
        };
        templates = {
          log_node = ''
            coalesce(
              if(current_working_copy, "●"),
              if(immutable, "⊗", "○"),
            )
          '';
        };
        # revsets = {
        #   log = "@ | bases | branches | curbranch::@ | @::nextbranch | downstream(@, branchesandheads)";
        # };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
