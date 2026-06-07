#include "postprocess.h"
#include <algorithm>
#include <cmath>

namespace poly {

Mat unwrap_output(const std::vector<float>& batched, int n_windows,
                  int fpw, int n_freq, int n_overlap, int n_times) {
    int n_olap = n_overlap / 2;                 // int(0.5*n_overlap)
    int kept = fpw - 2 * n_olap;                // frames kept per window
    Mat out;
    out.cols = n_freq;
    out.rows = n_times;
    out.d.assign((size_t)n_times * n_freq, 0.0f);
    int written = 0;
    for (int w = 0; w < n_windows && written < n_times; ++w) {
        for (int t = n_olap; t < fpw - n_olap && written < n_times; ++t) {
            const float* src = &batched[((size_t)w * fpw + t) * n_freq];
            std::copy(src, src + n_freq, &out.d[(size_t)written * n_freq]);
            ++written;
        }
    }
    return out;
}

// max(onsets, rescaled min-diff of frames). Mirrors get_infered_onsets.
// IMPORTANT: basic-pitch builds the padding with `np.zeros((n, ...))` and no
// dtype, so numpy promotes the WHOLE computation to float64. We must do the same
// in double — at float32 the rescaled frame_diff lands ~6e-8 off, which splits a
// held-note onset plateau and spawns a spurious peak (note boundary off by 1).
// Returns the inferred onsets as a double matrix (row-major, R*C).
static std::vector<double> get_infered_onsets(const Mat& onsets, const Mat& frames, int n_diff = 2) {
    const int R = frames.rows, C = frames.cols;
    std::vector<double> fd((size_t)R * C, 0.0);
    // frame_diff[t] = min_n( frames[t] - frames[t-n] ), n=1..n_diff ; t>=n else term=0
    for (int t = 0; t < R; ++t)
        for (int c = 0; c < C; ++c) {
            double mn = 0.0; bool first = true;
            for (int n = 1; n <= n_diff; ++n) {
                double prev = (t - n >= 0) ? (double)frames.at(t - n, c) : 0.0;
                double diff = (double)frames.at(t, c) - prev;
                if (first || diff < mn) { mn = diff; first = false; }
            }
            fd[(size_t)t * C + c] = mn;
        }
    for (auto& v : fd) if (v < 0.0) v = 0.0;
    for (int t = 0; t < n_diff && t < R; ++t)
        for (int c = 0; c < C; ++c) fd[(size_t)t * C + c] = 0.0;
    double onset_max = 0.0, fd_max = 0.0;
    for (float v : onsets.d) onset_max = std::max(onset_max, (double)v);
    for (double v : fd) fd_max = std::max(fd_max, v);
    std::vector<double> out((size_t)R * C);
    for (size_t i = 0; i < out.size(); ++i) {
        double rescaled = (fd_max != 0.0) ? (onset_max * fd[i]) / fd_max : 0.0;
        out[i] = std::max((double)onsets.d[i], rescaled);
    }
    return out;
}

// argrelmax along time (axis 0), order=1, strict greater than both neighbors,
// over the double inferred-onset matrix. Emits (t,f) in C order (t asc, f asc).
static void argrelmax_time(const std::vector<double>& m, int rows, int cols,
                           std::vector<std::pair<int,int>>& peaks) {
    auto at = [&](int r, int c) -> double { return m[(size_t)r * cols + c]; };
    for (int t = 1; t < rows - 1; ++t)
        for (int c = 0; c < cols; ++c)
            if (at(t, c) > at(t - 1, c) && at(t, c) > at(t + 1, c))
                peaks.emplace_back(t, c);
}

static float col_mean(const Mat& frames, int start, int end, int freq) {
    if (end <= start) return 0.0f;
    double s = 0.0;
    for (int t = start; t < end; ++t) s += frames.at(t, freq);
    return (float)(s / (double)(end - start));
}

std::vector<NoteEvent> output_to_notes_polyphonic(
    const Mat& note_in, const Mat& onset_in,
    float onset_thresh, float frame_thresh, int min_note_len,
    bool infer_onsets, bool melodia_trick, int energy_tol) {

    const int n_frames = note_in.rows;
    const int n_freq = note_in.cols;
    const Mat& frames = note_in;            // constrain_frequency is a no-op (min/max None)

    // Inferred onsets are computed/compared in double (matches numpy's float64 path).
    std::vector<double> onsets;
    if (infer_onsets) {
        onsets = get_infered_onsets(onset_in, frames);
    } else {
        onsets.resize(onset_in.d.size());
        for (size_t i = 0; i < onsets.size(); ++i) onsets[i] = (double)onset_in.d[i];
    }
    auto onset_at = [&](int r, int c) -> double { return onsets[(size_t)r * n_freq + c]; };

    // peak-thresholded onset positions, walked backwards in time
    std::vector<std::pair<int,int>> peaks;
    argrelmax_time(onsets, n_frames, n_freq, peaks);
    std::vector<std::pair<int,int>> onset_list;     // (time, freq), reversed
    for (auto it = peaks.rbegin(); it != peaks.rend(); ++it)
        if (onset_at(it->first, it->second) >= (double)onset_thresh)
            onset_list.push_back(*it);

    Mat rem = frames;                                // remaining_energy
    std::vector<NoteEvent> events;

    for (auto& pr : onset_list) {
        int note_start = pr.first, freq = pr.second;
        if (note_start >= n_frames - 1) continue;

        int i = note_start + 1, k = 0;
        while (i < n_frames - 1 && k < energy_tol) {
            if (rem.at(i, freq) < frame_thresh) ++k; else k = 0;
            ++i;
        }
        i -= k;                                       // back to last frame above thresh
        if (i - note_start <= min_note_len) continue;

        for (int t = note_start; t < i; ++t) {
            rem.at(t, freq) = 0.0f;
            if (freq < MAX_FREQ_IDX) rem.at(t, freq + 1) = 0.0f;
            if (freq > 0) rem.at(t, freq - 1) = 0.0f;
        }
        events.push_back({ note_start, i, freq + MIDI_OFFSET,
                           col_mean(frames, note_start, i, freq) });
    }

    if (melodia_trick) {
        while (true) {
            // argmax over rem in C order (first occurrence of the max)
            float best = frame_thresh; int bi = -1, bf = -1;
            for (int t = 0; t < n_frames; ++t)
                for (int c = 0; c < n_freq; ++c)
                    if (rem.at(t, c) > best) { best = rem.at(t, c); bi = t; bf = c; }
            if (bi < 0) break;                        // max(rem) <= frame_thresh

            int freq = bf, i_mid = bi;
            rem.at(i_mid, freq) = 0.0f;

            // forward
            int i = i_mid + 1, k = 0;
            while (i < n_frames - 1 && k < energy_tol) {
                if (rem.at(i, freq) < frame_thresh) ++k; else k = 0;
                rem.at(i, freq) = 0.0f;
                if (freq < MAX_FREQ_IDX) rem.at(i, freq + 1) = 0.0f;
                if (freq > 0) rem.at(i, freq - 1) = 0.0f;
                ++i;
            }
            int i_end = i - 1 - k;

            // backward
            i = i_mid - 1; k = 0;
            while (i > 0 && k < energy_tol) {
                if (rem.at(i, freq) < frame_thresh) ++k; else k = 0;
                rem.at(i, freq) = 0.0f;
                if (freq < MAX_FREQ_IDX) rem.at(i, freq + 1) = 0.0f;
                if (freq > 0) rem.at(i, freq - 1) = 0.0f;
                --i;
            }
            int i_start = i + 1 + k;
            if (i_end - i_start <= min_note_len) continue;

            events.push_back({ i_start, i_end, freq + MIDI_OFFSET,
                               col_mean(frames, i_start, i_end, freq) });
        }
    }

    return events;
}

} // namespace poly
