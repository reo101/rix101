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
      lib.concatLists [
        (optionals cfg.git.enable [
          # git
          gh
        ])
        (optionals cfg.jj.enable [
          # jujutsu
          watchman
          # Generate jj fix config from .pre-commit-config.yaml
          pkgs.custom.jj-gen-fix-config
        ])
      ];

    programs.git = mkIf cfg.git.enable {
      enable = true;
      package = pkgs.gitFull;
      signing = {
        signByDefault = true;
        inherit key;
      };
      lfs = {
        enable = true;
      };
      settings = {
        user = {
          inherit name email;
        };
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
          sign-on-push = true;
        };
        remotes = {
          origin.auto-track-bookmarks = "glob:*";
        };
        signing = {
          backend = "gpg";
          behaviour = "drop";
          inherit key;
        };
        fsmonitor = {
          backend = "watchman";
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
            merge-tool-edits-conflict-markers = true;
          };
        };
        revset-aliases = {
          "stragglers" = /* jj_revset */ ''
            (visible_heads() & mine()) ~ trunk()
          '';
          "bases" = /* jj_revset */ ''
            master | main
          '';
          "closest_bookmark(to)" = /* jj_revset */ ''
            heads(::to & bookmarks())
          '';
          "closest_pushable(to)" = /* jj_revset */ ''
            heads(::to & mutable() & ~description(exact:"") & (~empty() | merges()))
          '';
          "downstream(x,y)" = /* jj_revset */ ''
            (x::y) & y
          '';
          "branches" = /* jj_revset */ ''
            downstream(trunk(), bookmarks()) & mine()
          '';
          "branchesandheads" = /* jj_revset */ ''
            branches | (heads(trunk()::) & mine())
          '';
          "currbranch" = /* jj_revset */ ''
            latest(branches::@- & branches)
          '';
          "nextbranch" = /* jj_revset */ ''
            roots(@:: & branchesandheads)
          '';
        };
        aliases = {
          e = ["edit"];
          d = ["diff"];
          la = [ "log" "--revisions" "::" ];

          drag = ["bookmark" "advance"];
          sync = ["git" "fetch" "--all-remotes"];
          evolve = ["rebase" "--skip-emptied" "--simplify-parents" "--onto" "trunk()"];
          pullup = ["evolve" "-b" "stragglers"];
          touch = ["describe" "--reset-author" "--no-edit"];
          gh-pr = [
            "util" "exec" "--"
            (pkgs.writeShellScript "jj-gh-pr" ''
              set -euo pipefail

              trunk_bookmark=$(jj log -r 'trunk()' --no-graph --no-pager \
                -T 'separate("\n", local_bookmarks)' | head -1)
              if [[ -z "$trunk_bookmark" ]]; then
                echo "Error: trunk() has no local bookmark; cannot determine base branch." >&2
                exit 1
              fi

              found=false
              while IFS=$'\t' read -r -u 3 change bookmark_line; do
                [[ -z "$bookmark_line" ]] && continue
                found=true

                head=$(echo "$bookmark_line" | head -1)

                base=$(jj log -r "closest_bookmark(parents($change))" --no-graph --no-pager \
                  -T 'separate("\n", local_bookmarks)' | head -1)

                if [[ -z "$base" ]]; then
                  base="$trunk_bookmark"
                fi

                echo ""
                echo "=== PR: $head -> $base ==="
                existing=$(gh pr list --head "$head" --json url -q '.[0].url' 2>/dev/null || true)
                if [[ -n "$existing" ]]; then
                  echo "  PR already exists: $existing"
                fi
                read -r -p "Create PR? [y/N] " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                  gh pr create --head "$head" --base "$base"
                fi
              done 3< <(jj log -r 'branches()' --no-graph --no-pager --reverse \
                -T 'change_id ++ "\t" ++ separate("\n", local_bookmarks) ++ "\n"')

              if ! "$found"; then
                echo "No bookmarks found on branches."
              fi
            '')
          ];
          gen-fix-config = [
            "util" "exec" "--" "jj-gen-fix-config"
          ];

          pl = ["obslog" "-p"];

          # cl = ["git" "push" "-c" "@-"];
          # push = ["git" "push" "--all"];

          configure = ["config" "edit" "--repo"];

          ".." = ["next" "--edit"];
          ",," = ["prev" "--edit"];
        };
        template-aliases = {
          "format_timestamp(ts)" = /* jj_template */ ''
            if(
              ts.after("2 weeks ago"),
              ts.ago(),
              ts.format("%b %d, %Y %H:%M"),
            )
          '';

          "has_matching_local_remote" = /* jj_template */ ''
            remote_bookmarks.any(|r| local_bookmarks.any(|l| l.name() == r.name()))
          '';

          "is_stray" = /* jj_template */ ''
            !immutable &&
            !hidden &&
            !self.contained_in("trunk()::") &&
            !(remote_bookmarks.len() > 0 && !has_matching_local_remote)
          '';

          "format_short_id(id)" = /* jj_template */ ''
            id.shortest(12).prefix() ++ id.shortest(12).rest()
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
              label(
                coalesce(
                  if(hidden, "hidden"),
                  if(is_stray, "stray"),
                ),
                coalesce(
                  if(current_working_copy, "●"),
                  if(immutable, "⊗"),
                  "○",
                ),
              ),
            )
          '';
          git_push_bookmark = /* jj_template */ ''
            "reo101/" ++ change_id.short()
          '';
          draft_commit_description = /* jj_template */ ''
            builtin_draft_commit_description_with_diff
          '';
        };
        colors = {
          stray = { fg = "bright red"; bold = true; };
          hidden = { dim = true; };
          "hidden change_id" = "bright black";
          "hidden commit_id" = "bright black";
          "node hidden" = { fg = "bright black"; };
        };
        revsets = {
          # log = "@ | bases | branches | curbranch::@ | @::nextbranch | downstream(@, branchesandheads)";
          log = "present(@) | present(trunk()) | ancestors(remote_bookmarks().. | @.., 8)";
          bookmark-advance-to = "@-";
        };
      };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
