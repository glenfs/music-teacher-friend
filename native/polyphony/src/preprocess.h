// Audio -> model input windows. Mirrors basic-pitch get_audio_input/
// window_audio_file: resample to 22050 mono, prepend overlap/2 zeros, slice into
// AUDIO_N_SAMPLES windows stepping by hop_size, zero-pad the tail.
#pragma once
#include <vector>
#include <cstdint>

namespace poly {

constexpr int AUDIO_N_SAMPLES = 43844;
constexpr int FFT_HOP = 256;
constexpr int N_OVERLAPPING_FRAMES = 30;

// Resample mono `in` (at in_rate) to 22050 Hz. Linear interpolation with a
// light pre-lowpass when downsampling (anti-alias). Good enough for note
// detection; the model keys on low/mid partials.
std::vector<float> resample_to_22050(const float* in, size_t n, int in_rate);

// Build the windowed model input. Returns flattened (n_windows*AUDIO_N_SAMPLES)
// row-major; sets n_windows and original_length (resampled length pre-padding).
std::vector<float> window_audio(const std::vector<float>& audio22050,
                                int& n_windows, int& original_length);

// floor(original_length * ANNOTATIONS_FPS / AUDIO_SAMPLE_RATE)
int n_output_frames(int original_length);

} // namespace poly
