{ pkgs, ... }:

{
  # add package to include in the image, ie. packages that you don't
  # want to install manually later
  packages = [ "tcpdump" ];

  disabledServices = [ "dnsmasq" ];

  # include files in the images.
  # to set UCI configuration, create a uci-defauts scripts as per
  # official OpenWRT ImageBuilder recommendation.
  files = pkgs.runCommand "image-files" {} ''
    mkdir -p $out/etc/uci-defaults
    cat > $out/etc/uci-defaults/99-custom <<EOF
    uci -q batch << EOI
    set system.@system[0].hostname='testap'
    commit
    EOI
    EOF
  '';
}
