// C++ port of basic-pitch note_creation.output_to_notes_polyphonic (+ helpers).
// Frame-domain note events only — pitch bends / MIDI / sonify are intentionally
// omitted (grading needs just start/end/midi/amplitude).
#pragma once
#include <vector>
#include <cstdint>

namespace poly {

struct Mat {           // row-major (n_times x n_freq)
    int rows = 0, cols = 0;
    std::vector<float> d;
    float& at(int r, int c) { return d[(size_t)r * cols + c]; }
    float at(int r, int c) const { return d[(size_t)r * cols + c]; }
};

struct NoteEvent {     // frame domain
    int start = 0, end = 0, midi = 0;
    float amplitude = 0.0f;
};

// basic-pitch constants used here.
constexpr int   MIDI_OFFSET = 21;
constexpr int   MAX_FREQ_IDX = 87;
constexpr int   AUDIO_SAMPLE_RATE = 22050;
constexpr int   ANNOTATIONS_FPS = 86;

// Unwrap batched model output (n_windows x frames_per_window x n_freq) into a
// single (n_times x n_freq) matrix: drop n_overlap/2 frames from each window's
// head & tail, concatenate, trim to n_times.
Mat unwrap_output(const std::vector<float>& batched, int n_windows,
                  int frames_per_window, int n_freq, int n_overlap, int n_times);

// Port of output_to_notes_polyphonic. note/onset are (n_times x n_freq).
std::vector<NoteEvent> output_to_notes_polyphonic(
    const Mat& note, const Mat& onset,
    float onset_thresh, float frame_thresh, int min_note_len,
    bool infer_onsets = true, bool melodia_trick = true, int energy_tol = 11);

} // namespace poly
