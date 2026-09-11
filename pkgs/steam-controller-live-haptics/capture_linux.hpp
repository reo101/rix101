#pragma once
// Linux/Steam Deck: PulseAudio/PipeWire capture via libpulse-simple.
// Set default source to sink monitor first:
//   pactl set-default-source $(pactl get-default-sink).monitor
#include <pulse/simple.h>
#include <pulse/error.h>
#include <vector>
#include <cstdio>
struct PulseCapture {
  std::shared_ptr<MockAudioSink> sink_;
  PulseCapture(std::shared_ptr<MockAudioSink> s) : sink_(s) {}
  void run(std::atomic<bool> &running) {
    pa_sample_spec ss; ss.format = PA_SAMPLE_S16LE; ss.rate = 48000; ss.channels = 2;
    pa_buffer_attr attr{};
    attr.maxlength = (uint32_t)(48000 * 4 * 0.10);
    attr.tlength   = (uint32_t)-1;
    attr.prebuf    = (uint32_t)-1;
    attr.minreq    = (uint32_t)-1;
    attr.fragsize  = (uint32_t)(48000 * 4 * 0.010);
    int err = 0;
    const char *source = std::getenv("PULSE_SOURCE");
    pa_simple *p = pa_simple_new(nullptr, "LiveHaptics", PA_STREAM_RECORD, source, "haptics", &ss, nullptr, &attr, &err);
    if (!p) { printf("Pulse/PipeWire capture failed: %s\n", pa_strerror(err)); return; }
    sink_->decim = 48000 / g_rate;
    printf("Pulse/PipeWire capture started: 2 ch, 48000 Hz (10ms fragments)\n");
    uint8_t buf[1920];
    while (running.load()) {
      if (pa_simple_read(p, buf, sizeof(buf), &err) < 0) { printf("capture error: %s\n", pa_strerror(err)); break; }
      const int16_t *st = (const int16_t *)buf;
      size_t frames = sizeof(buf) / 4;
      std::vector<int16_t> out(frames * 4);
      for (size_t f = 0; f < frames; ++f) {
        int16_t L = st[f*2], R = st[f*2+1], M = (int16_t)(((int32_t)L + R) / 2);
        out[f*4] = L; out[f*4+1] = M; out[f*4+2] = L; out[f*4+3] = R;
      }
      sink_->write_audio((const uint8_t *)out.data(), out.size() * 2);
    }
    pa_simple_free(p);
  }
};
using CaptureBackend = PulseCapture;
