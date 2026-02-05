import ./common.nix {
  release = "25.12.0";
  arch = "aarch64_cortex-a53";
  sha256sumsHash = "sha256-WmmnoPCy+WxWR4VAK2D3Ad/jQfGtL5d5CMPQDe5yPN8=";
  feedHashes = {
    base = "sha256-spOK6+MDCakXa0sqnjekDhlfR95Ajp6OpqPk6MIX2RM=";
    luci = "sha256-vfrthyIyVKbk/ENtfmIIXlCUb8vF0Y+WvbKp2r71lB0=";
    packages = "sha256-n7MvzJ24aBD4AZCicsLqdphfvu0YLiYSwA3M76WXq/Y=";
    routing = "sha256-fkhYMmO4WGWbjGHGJ8jfz1CB5WBq62ApXExm3O50U6g=";
    telephony = "sha256-sIn+P306moNbI7JAQtyzLK8N/84alSngToVQQuUHnGk=";
  };
}
