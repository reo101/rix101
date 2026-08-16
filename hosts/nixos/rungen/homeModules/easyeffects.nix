{ ... }:

{
  services.easyeffects = {
    enable = true;
    preset.input = "mic-filter";
    extraPresets = {
      mic-filter = {
        input = {
          blocklist = [
          ];
          "plugins_order" = [
            "stereo_tools#0"
            "deepfilternet#0"
            "echo_canceller#0"
            "equalizer#0"
          ];
          "echo_canceller#0" = {
            bypass = false;
          };
          "deepfilternet#0" = {
            bypass = false;
            input-gain = 0.0;
            output-gain = 0.0;
            # docs: 70-80dB is the balanced sweet spot; default 100 maxes out
            # attenuation but starts eating speech intelligibility.
            attenuation-limit = 75.0;
            # docs: -15..-30 dB, but the schema clamps at -15 (schema min).
            min-processing-threshold = -15.0;
            max-erb-processing-threshold = 30.0;
            max-df-processing-threshold = 20.0;
            # 0 = smallest buffer, best real-time performance.
            min-processing-buffer = 0;
            # schema caps at 0.05; higher = harsher post-filter, 0.02 is stock.
            post-filter-beta = 0.02;
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
                  frequency = 80.0;
                  gain = 0.0;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 0.707;
                  slope = "x2";
                  solo = false;
                  type = "Hi-pass";
                  width = 4.0;
                };
                band1 = {
                  frequency = 120.0;
                  gain = 0.0;
                  mode = "RLC (BT)";
                  mute = false;
                  q = 8.0;
                  slope = "x1";
                  solo = false;
                  type = "Notch";
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
