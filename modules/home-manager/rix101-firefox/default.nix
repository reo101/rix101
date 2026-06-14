{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.rix101.firefox;
  supportedBrowsers = [
    "firefox"
    "floorp"
    "librewolf"
  ];

  browserConfig = {
    enable = true;

    policies.SearchEngines.Default = "Startpage";

    profiles."default" = {
      settings = {
        # Always use local fonts
        "browser.display.use_document_fonts" = 0;
        # No `Home` button
        "browser.engagement.home-button.has-removed" = true;
        # Clean `New Tab` page
        "browser.newtabpage.enabled" = false;
        # No separate search engine for private mode
        "browser.search.separatePrivateDefault" = false;
        # Clean startup page
        "browser.startup.homepage" = "chrome://browser/content/blanktab.html";
        # No bookmarks bar
        "browser.toolbars.bookmarks.visibility" = "never";
        # No Firefox translations
        "browser.translations.enable" = false;
        # Navigation bar elements ordering
        "browser.uiCustomization.state" = {
          placements.nav-bar = [
            "back-button"
            "forward-button"
            "stop-reload-button"
            "history-panelmenu"
            "bookmarks-menu-button"
            "vertical-spacer"
            "urlbar-container"
            "search-container"
            "developer-button"
            "downloads-button"
            "fxa-toolbar-menu-button"
            "unified-extensions-button"
            "ublock0_raymondhill_net-browser-action"
          ];
          # WARN: 触るな！
          currentVersion = 23;
        };
        # Skip onboarding
        "browser.urlbar.quickactions.timesShownOnboardingLabel" = 1;
        # Disable floating search engine selector, doesn't mesh well with <./bottomBar.css>
        # (see <https://github.com/MrOtherGuy/firefox-csshacks/issues/553>)
        "browser.urlbar.scotchBonnet.enableOverride" = false;
        # No recent searches in autocomplete
        "browser.urlbar.suggest.recentsearches" = false;
        # No primary selection population (`Primary` vs `Secondary` vs `Clipboard` selection shenanigans)
        "clipboard.autocopy" = false;
        # Spawn devtools in a vertical split to the right
        "devtools.toolbox.host" = "right";
        # Default dark theme
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        # Highlight all `Ctrl+F` matches
        "findbar.highlightAll" = true;
        # Scroll with `Mouse3` (like on Windows) instead of pasting
        "general.autoScroll" = true;
        # No spellchecking
        "layout.spellcheckDefault" = 0;
        # No pasting with `Mouse3`
        "middlemouse.paste" = false;
        # Paranoid for `XOriginPolicy`
        "network.http.referer.XOriginPolicy" = 2;
        # Paranoid for `DNS` over `HTTPS`
        "network.trr.mode" = 3;
        # Keep history and downloads
        "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads" = false;
        # Clear formdata
        "privacy.clearOnShutdown_v2.formdata" = true;
        # Clear site settings
        "privacy.clearOnShutdown_v2.siteSettings" = true;
        # LARP as another viewport (against fingerprinting screensize)
        "privacy.resistFingerprinting.letterboxing" = true;
        # LARP as `English` whereever possible
        "privacy.spoof_english" = 2;
        # Allow *some* tracking, to make some big sites work
        "privacy.trackingprotection.allow_list.baseline.enabled" = false;
        # No sidebar
        "sidebar.visibility" = "hide-sidebar";
        # Allow custom stylesheets (i.e. `userChrome`)
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };

      userChrome = lib.concatStringsSep "\n" [
        /* css */ ''
          .browserContainer:not(:has(#statuspanel[type="status"])) {
            background:
              url(
               "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgMTAgMTAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHBhdGggZmlsbD0iI0ZGRiIgZD0iTTAgMGgxMHYxMEgweiIvPjxjaXJjbGUgY3g9IjUiIHI9IjIiIGZpbGw9IiNGRkRCRjAiLz48Y2lyY2xlIGN4PSI1IiBjeT0iMTAiIHI9IjIiIGZpbGw9IiNGRkRCRjAiLz48Y2lyY2xlIGN5PSI1IiByPSIyIiBmaWxsPSIjRkZEQkYwIi8+PGNpcmNsZSBjeD0iMTAiIGN5PSI1IiByPSIyIiBmaWxsPSIjRkZEQkYwIi8+PC9zdmc+")
              0 0 / 200px 200px
              !important;
          }

          .browserContainer:has(#statuspanel[type="status"]) {
            background:
              url("file://${
                let
                  og = pkgs.fetchurl {
                    url = "https://static.wikia.nocookie.net/doki-doki-literature-club/images/d/d8/S_kill_early.png";
                    hash = "sha256-aSOZOX6dK1avohEVHzr3hGa1PazDD3lADqZbL9JFrfQ=";
                  };
                  removeColour =
                    {
                      image,
                      fuzz ? 10,
                      colour ? "white",
                      ...
                    }:
                    pkgs.runCommand "${image.name}.png"
                      {
                        buildInputs = [
                          pkgs.imagemagick
                        ];
                      }
                      ''
                        magick ${image} \
                          -fuzz ${builtins.toString fuzz}% \
                          -transparent ${lib.escapeShellArg colour} \
                          $out
                      '';
                in
                removeColour {
                  image = og;
                  fuzz = 20;
                  colour = "white";
                }
              }")
              no-repeat top left 20%,
              repeating-radial-gradient(#fff 0 0.0001%, darkgray 0 0.0002%)
              50% 0 / 101% 101%,
              repeating-conic-gradient(#fff 0 0.0001%, darkgray 0 0.0002%)
              60% 60% / 101% 101%
              !important;
            background-blend-mode: normal, darken;
          }
        ''
        (builtins.readFile ./bottomBar.css)
      ];
    };
  };
in
{
  options.rix101.firefox = {
    enable = lib.mkEnableOption "rix101 Firefox setup";

    browsers = lib.mkOption {
      type = lib.types.listOf (lib.types.enum supportedBrowsers);
      description = ''
        Firefox-like Home Manager `programs.*` modules to configure
      '';
      default = [ "librewolf" ];
      apply = lib.unique;
    };
  };

  config = lib.mkIf cfg.enable {
    programs = lib.genAttrs cfg.browsers (_: browserConfig);
  };
}
