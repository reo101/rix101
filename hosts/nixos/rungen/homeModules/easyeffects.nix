{ ... }:

{
  services.easyeffects = {
    enable = true;
    preset = "mic-filter";
    extraPresets = {
      mic-filter = {
        input = {
          blocklist = [
          ];
          "plugins_order" = [
            "stereo_tools#0"
            "rnnoise#0"
            "echo_canceller#0"
            "equalizer#0"
          ];
          "echo_canceller#0" = {
            bypass = false;
          };
          "rnnoise#0" = {
            bypass = false;
            enable-vad = true;
            input-gain = 3.0;
            model-name = "";
            output-gain = 0.0;
            release = 5.0;
            vad-thres = 1.0;
            wet = 0.0;
          };
          "stereo_tools#0" = {
            balance-in = 0.0;
            balance-out = 0.0;
            bypass = false;
            delay = 0.0;
            input-gain = 0.0;
            middle-level = 0.0;
            middle-panorama = 0.0;
            mode = "LR > MS (Stereo to Mid-Side)";
            mutel = false;
            muter = false;
            output-gain = 0.0;
            phasel = false;
            phaser = false;
            sc-level = 1.0;
            side-balance = 0.0;
            side-level = 0.0;
            softclip = false;
            stereo-base = 0.0;
            stereo-phase = 0.0;
          };
          "equalizer#0" =
            let
              eq-cfg = {
                band0 = {
                  frequency = 30.0;
                  gain = 0.0;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 0.7162904212787583;
                  slope = "x1";
                  solo = false;
                  type = "Hi-shelf";
                  width = 4.0;
                };
                band1 = {
                  frequency = 166.0;
                  gain = 4.0;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 0.72;
                  slope = "x1";
                  solo = false;
                  type = "Bell";
                  width = 4.0;
                };
                band2 = {
                  frequency = 850.0;
                  gain = -2.0;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 0.72;
                  slope = "x1";
                  solo = false;
                  type = "Bell";
                  width = 4.0;
                };
                band3 = {
                  frequency = 5000.0;
                  gain = 3.5;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 0.72;
                  slope = "x1";
                  solo = false;
                  type = "Bell";
                  width = 4.0;
                };
              };
            in
            {
              balance = 0.0;
              bypass = false;
              input-gain = 0.0;
              left = eq-cfg;
              right = eq-cfg;
              mode = "IIR";
              num-bands = 4;
              output-gain = 0.0;
              pitch-left = 0.0;
              pitch-right = 0.0;
              split-channels = false;
            };
        };
      };
    };
  };
}
