{ inputs, config, pkgs, lib, ... }:

{
  environment.systemPackages = [
    config.services.kanata.package
  ];

  services.kanata = {
    enable = true;
    package = pkgs.kanata-with-cmd;
    keyboards = {
      integrated = {
        devices = [
          "/dev/input/by-path/platform-2a9b30000.input-event-kbd"
        ];
        extraDefCfg = ''
          process-unmapped-keys yes
        '';
        config = /* kmonad */ ''
          ;; (defcfg
          ;;   process-unmapped-keys yes
          ;; )
          (defsrc
            a   s   d   f   j   k   l   ;
            caps
          )
          (defvar
            tap-time 200
            hold-time 150
            caps-hold-time 500

            left-hand-keys (
              q w e r t
              a s d f g
              z x c v b
            )
            right-hand-keys (
              y u i o p
              h j k l ;
              n m , . /
            )
          )
          (deflayer base
            @a  @s  @d  @f  @j  @k  @l  @;
            @caps-ctrl
          )

          (deflayer nomods
            a   s   d   f   j   k   l   ;
            caps
          )
          (deffakekeys
            to-base (layer-switch base)
          )
          (defalias
            tap (multi
              (layer-switch nomods)
              (on-idle-fakekey to-base tap 20)
            )

            a (tap-hold-release-keys $tap-time $hold-time (multi a @tap) lsft ()) ;; $left-hand-keys)
            s (tap-hold-release-keys $tap-time $hold-time (multi s @tap) lctl ()) ;; $left-hand-keys)
            d (tap-hold-release-keys $tap-time $hold-time (multi d @tap) lmet ()) ;; $left-hand-keys)
            f (tap-hold-release-keys $tap-time $hold-time (multi f @tap) lalt ()) ;; $left-hand-keys)

            j (tap-hold-release-keys $tap-time $hold-time (multi j @tap) ralt ()) ;; $right-hand-keys)
            k (tap-hold-release-keys $tap-time $hold-time (multi k @tap) rmet ()) ;; $right-hand-keys)
            l (tap-hold-release-keys $tap-time $hold-time (multi l @tap) rctl ()) ;; $right-hand-keys)
            ; (tap-hold-release-keys $tap-time $hold-time (multi ; @tap) rsft ()) ;; $right-hand-keys)
          )
          (defalias
            caps-ctrl (tap-hold-press $tap-time $caps-hold-time esc caps)
          )
        '';
      };
    };
  };
}
