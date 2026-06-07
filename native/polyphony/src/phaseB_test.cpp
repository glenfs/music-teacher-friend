// Phase B: validate the C++ port against the Python reference, two ways per clip:
//   A) postprocess parity (EXACT): feed the bit-identical dumped note/onset bins
//      into output_to_notes_polyphonic; events must match exactly (start/end/midi
//      identical, amplitude within 1e-4). Proves the port logic is correct.
//   B) full-native (±1 frame): input.bin -> C++ ORT -> unwrap -> postprocess.
//      Cross-runtime ORT float (~1e-7) can shift a note boundary by ONE frame at
//      a threshold/plateau, so boundaries are allowed ±1; count/midi must match.
//
// Usage: phaseB_test <polyphony_dir>

#include <onnxruntime_cxx_api.h>
#include "postprocess.h"

#include <cstdio>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cmath>

using poly::Mat; using poly::NoteEvent;

static std::vector<float> read_bin(const std::string& p) {
    std::ifstream f(p, std::ios::binary | std::ios::ate);
    if (!f) return {};
    std::streamsize n = f.tellg(); f.seekg(0);
    std::vector<float> v(n / sizeof(float));
    f.read(reinterpret_cast<char*>(v.data()), n);
    return v;
}
static std::wstring widen(const std::string& s) { return std::wstring(s.begin(), s.end()); }

struct Dims { int n_windows, n_times, n_freq, fpw, n_overlap, orig_len, min_note_len; float onset_th, frame_th; };
static bool read_dims(const std::string& p, Dims& d) {
    std::ifstream f(p); if (!f) return false;
    f >> d.n_windows >> d.n_times >> d.n_freq >> d.fpw >> d.n_overlap >> d.orig_len
      >> d.min_note_len >> d.onset_th >> d.frame_th;
    return true;
}
static std::vector<NoteEvent> read_events(const std::string& p) {
    std::vector<NoteEvent> v; std::ifstream f(p); std::string line;
    while (std::getline(f, line)) {
        if (line.empty()) continue;
        std::istringstream ss(line); NoteEvent e; double a;
        ss >> e.start >> e.end >> e.midi >> a; e.amplitude = (float)a;
        v.push_back(e);
    }
    return v;
}
static void sort_events(std::vector<NoteEvent>& v) {
    std::sort(v.begin(), v.end(), [](const NoteEvent& a, const NoteEvent& b) {
        if (a.start != b.start) return a.start < b.start;
        if (a.midi != b.midi) return a.midi < b.midi;
        return a.end < b.end;
    });
}
static Mat load_mat(const std::string& p, int rows, int cols) {
    Mat m; m.rows = rows; m.cols = cols; m.d = read_bin(p); return m;
}
static double maxdiff(const std::vector<float>& a, const Mat& b) {
    if (a.size() != b.d.size()) return 1e9;
    double m = 0; for (size_t i = 0; i < a.size(); ++i) m = std::max(m, std::fabs((double)a[i] - b.d[i]));
    return m;
}

// Compare event lists. tol_frames = allowed |start|,|end| slack. Returns ok + worst amp diff.
static bool cmp_events(std::vector<NoteEvent> a, std::vector<NoteEvent> b, int tol_frames, double& amp_d) {
    sort_events(a); sort_events(b);
    amp_d = 0;
    if (a.size() != b.size()) return false;
    for (size_t i = 0; i < a.size(); ++i) {
        if (a[i].midi != b[i].midi) return false;
        if (std::abs(a[i].start - b[i].start) > tol_frames) return false;
        if (std::abs(a[i].end - b[i].end) > tol_frames) return false;
        amp_d = std::max(amp_d, (double)std::fabs(a[i].amplitude - b[i].amplitude));
    }
    return true;
}

int main(int argc, char** argv) {
    std::string base = (argc > 1) ? argv[1] : ".";
    std::string td = base + "/testdata/";
    const char* names[] = { "C_major_(C4)", "G7_dom7", "single_bass_E2", "Cmaj_long_4s" };

    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "polyB");
    Ort::SessionOptions opts; opts.SetIntraOpNumThreads(1);
    Ort::Session session(env, widen(base + "/models/nmp.onnx").c_str(), opts);
    Ort::MemoryInfo mem = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    const char* in_names[] = { "serving_default_input_2:0" };
    const char* out_names[] = { "StatefulPartitionedCall:2", "StatefulPartitionedCall:1" }; // onset, note

    bool all_pass = true;
    for (const char* name : names) {
        Dims d;
        if (!read_dims(td + name + ".dims.txt", d)) { std::printf("%s: no dims\n", name); all_pass = false; continue; }
        auto ref = read_events(td + name + ".events.txt");

        // --- A) EXACT: postprocess on the bit-identical reference bins ---
        Mat noteR = load_mat(td + name + ".note.bin", d.n_times, d.n_freq);
        Mat onsetR = load_mat(td + name + ".onset.bin", d.n_times, d.n_freq);
        auto evA = poly::output_to_notes_polyphonic(noteR, onsetR, d.onset_th, d.frame_th, d.min_note_len);
        double ampA; bool okA = cmp_events(evA, ref, 0, ampA) && ampA < 1e-4;
        if (!okA) {
            auto a = evA; auto b = ref; sort_events(a); sort_events(b);
            std::printf("    [%s] A debug: cpp(%zu):", name, a.size());
            for (auto& e : a) std::printf(" (%d,%d,%d)", e.start, e.end, e.midi);
            std::printf("  ref(%zu):", b.size());
            for (auto& e : b) std::printf(" (%d,%d,%d)", e.start, e.end, e.midi);
            std::printf("\n");
        }

        // --- B) full native: input.bin -> ORT -> unwrap -> postprocess ---
        std::vector<float> input = read_bin(td + name + ".input.bin");
        std::vector<int64_t> in_shape = { d.n_windows, 43844, 1 };
        Ort::Value in_t = Ort::Value::CreateTensor<float>(mem, input.data(), input.size(),
                                                          in_shape.data(), in_shape.size());
        auto outs = session.Run(Ort::RunOptions{ nullptr }, in_names, &in_t, 1, out_names, 2);
        float* onset_raw = outs[0].GetTensorMutableData<float>();
        float* note_raw = outs[1].GetTensorMutableData<float>();
        std::vector<float> onset_v(onset_raw, onset_raw + (size_t)d.n_windows * d.fpw * d.n_freq);
        std::vector<float> note_v(note_raw, note_raw + (size_t)d.n_windows * d.fpw * d.n_freq);
        Mat onset = poly::unwrap_output(onset_v, d.n_windows, d.fpw, d.n_freq, d.n_overlap, d.n_times);
        Mat note = poly::unwrap_output(note_v, d.n_windows, d.fpw, d.n_freq, d.n_overlap, d.n_times);
        double dn = maxdiff(read_bin(td + name + ".note.bin"), note);
        double don = maxdiff(read_bin(td + name + ".onset.bin"), onset);
        auto evB = poly::output_to_notes_polyphonic(note, onset, d.onset_th, d.frame_th, d.min_note_len);
        double ampB; bool okB = cmp_events(evB, ref, 1, ampB);  // ±1 frame

        bool pass = okA && okB && dn < 1e-4 && don < 1e-4;
        all_pass = all_pass && pass;
        std::printf("%-16s events=%zu | A(exact) %s ampd=%.1e | B(native ±1f) %s unwrap|d|=%.1e | %s\n",
            name, ref.size(), okA ? "OK" : "FAIL", ampA, okB ? "OK" : "FAIL",
            std::max(dn, don), pass ? "PASS" : "FAIL");
    }
    std::printf("PHASE_B %s\n", all_pass ? "PASS" : "FAIL");
    return all_pass ? 0 : 1;
}
