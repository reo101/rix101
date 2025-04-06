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
          inherit name email;
        };
        git = {
          fetch = ["origin" "upstream"];
          push = "origin";
          private-commits = "description(glob:'wip:*')";
          auto-local-bookmark = true;
          push-bookmark-prefix = "reo101/";
          sign-on-push = true;
        };
        signing = {
          backend = "gpg";
          behaviour = "drop";
          inherit key;
        };
        core = {
          fsmonitor = "watchman";
          watchman = {
            register-snapshot-trigger = true;
          };
        };
        ui = mkMerge [
          {
            color = "always";
            show-cryptographic-signatures = true;
          }
          (mkIf cfg.jj.nvim {
            # pager = "nvim";
            editor = "nvim -b";
            diff-editor = [
              "nvim"
              "-c"
              "DiffEditor $left $right $output"
            ];
          })
        ];
        merge-tools = {
          diffconflicts = mkIf cfg.jj.nvim {
            program = "nvim";
            merge-args = [
              "-c" "let g:jj_diffconflicts_marker_length=$marker_length"
              "-c" "JJDiffConflicts!" "$output" "$base" "$left" "$right"
            ];
            # NOTE: for no history view
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
          s = ["status"];
          e = ["edit"];
          l = ["log"];
          d = ["diff"];

          dragmain = ["bookmark" "set" "main" "-r" "@-"];
          sync = ["git" "fetch" "--all-remotes"];
          evolve = ["rebase" "--skip-emptied" "-d" "trunk()"];
          pullup = ["evolve" "-s" "all:stragglers"];

          xl = ["log" "-r" "all()"];
          pl = ["obslog" "-p"];

          # cl = ["git" "push" "-c" "@-"];
          # push = ["git" "push" "--all"];

          configure = ["config" "edit" "--repo"];

          ".." = ["edit" "-r" "@-"];
          ",," = ["edit" "-r" "@+"];
        };
        template-aliases = {
          "format_timestamp(ts)" = /* jj_template */ ''
            if(
              ts.after("2 weeks ago"),
              ts.ago(),
              ts.format("%b %d, %Y %H:%M"),
            )
          '';

          "format_short_id(id)" = /* jj_template */ ''
            id.shortest(12).prefix() ++ "[" ++ id.shortest(12).rest() ++ "]"
          '';
          "format_timestamp(timestamp)" = /* jj_template */ ''
            timestamp.ago()
          '';
          "format_short_signature(signature)" = /* jj_template */ ''
            signature.name()
          '';
          "format_detailed_signature(signature)" = /* jj_template */ ''
            signature.name() ++ " (" ++ signature.email() ++ ")"
          '';

          builtin_log_detailed = /* jj_template */ ''
            "\n\n\n" ++
            concat(
              "Change ID: " ++ format_short_id(change_id) ++ "\n",
              "Commit ID: " ++ format_short_id(commit_id) ++ "\n",
              surround("Bookmarks: ", "\n", separate(" ", local_bookmarks, remote_bookmarks)),
              surround("Tags     : ", "\n", tags),
              if(config("ui.show-cryptographic-signatures").as_boolean(),
                "Signature: " ++ format_detailed_cryptographic_signature(signature),
                "Signature: (not shown)"),
              "\n",
              "Author   : " ++ format_detailed_signature(author) ++ "\n",
              "Committer: " ++ format_detailed_signature(committer)  ++ "\n",
                indent("    ",
                coalesce(description, label(if(empty, "empty"), description_placeholder) ++ "\n")),
              "\n",
            )
          '';
        };
        templates = {
          log_node = /* jj_template */ ''
            coalesce(
              if(!self, label("elided", "▪")),
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
