#include "preprocess.h"
#include <cmath>
#include <algorithm>

namespace poly {

static constexpr int TARGET_SR = 22050;
static constexpr int ANNOTATIONS_FPS = 86;

std::vector<float> resample_to_22050(const float* in, size_t n, int in_rate) {
    if (n == 0) return {};
    if (in_rate == TARGET_SR) return std::vector<float>(in, in + n);

    double ratio = (double)TARGET_SR / (double)in_rate;
    size_t out_n = (size_t)std::floor((double)n * ratio);
    std::vector<float> out(out_n);

    // Anti-alias when downsampling: simple moving-average box of width ~in/out.
    // Cheap, zero-phase-ish, kills the worst aliasing before linear resample.
    const float* src = in;
    std::vector<float> lp;
    if (in_rate > TARGET_SR) {
        int half = std::max(1, (int)std::lround((double)in_rate / TARGET_SR / 2.0));
        int win = 2 * half + 1;
        lp.resize(n);
        double inv = 1.0 / win;
        double acc = 0.0;
        for (int i = -half; i <= half; ++i) acc += in[std::min((size_t)std::max(0, i), n - 1)];
        for (size_t i = 0; i < n; ++i) {
            lp[i] = (float)(acc * inv);
            size_t add = std::min(n - 1, i + half + 1);
            long sub = (long)i - half;
            acc += in[add] - in[(size_t)std::max(0L, sub)];
        }
        src = lp.data();
    }

    // Linear interpolation onto the 22050 grid.
    double step = (double)in_rate / (double)TARGET_SR;
    for (size_t i = 0; i < out_n; ++i) {
        double pos = (double)i * step;
        size_t i0 = (size_t)pos;
        double frac = pos - (double)i0;
        float a = src[std::min(i0, n - 1)];
        float b = src[std::min(i0 + 1, n - 1)];
        out[i] = (float)(a + (b - a) * frac);
    }
    return out;
}

std::vector<float> window_audio(const std::vector<float>& audio22050,
                                int& n_windows, int& original_length) {
    original_length = (int)audio22050.size();
    int overlap_len = N_OVERLAPPING_FRAMES * FFT_HOP;   // 7680
    int hop = AUDIO_N_SAMPLES - overlap_len;             // 36164
    int front = overlap_len / 2;                         // 3840

    // padded = [zeros(front), audio]
    std::vector<float> padded((size_t)front + audio22050.size(), 0.0f);
    std::copy(audio22050.begin(), audio22050.end(), padded.begin() + front);

    // windows step by hop over padded; each window AUDIO_N_SAMPLES, tail zero-padded
    int n = (int)padded.size();
    int nw = 0;
    for (int i = 0; i < n; i += hop) nw++;
    if (nw == 0) nw = 1;
    n_windows = nw;

    std::vector<float> out((size_t)nw * AUDIO_N_SAMPLES, 0.0f);
    int w = 0;
    for (int i = 0; i < n; i += hop, ++w) {
        for (int s = 0; s < AUDIO_N_SAMPLES; ++s) {
            int idx = i + s;
            out[(size_t)w * AUDIO_N_SAMPLES + s] = (idx < n) ? padded[idx] : 0.0f;
        }
    }
    return out;
}

int n_output_frames(int original_length) {
    return (int)std::floor((double)original_length * (double)ANNOTATIONS_FPS / (double)TARGET_SR);
}

} // namespace poly
