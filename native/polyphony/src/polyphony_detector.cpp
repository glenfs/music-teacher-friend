#include "polyphony_detector.h"
#include "preprocess.h"
#include "postprocess.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <chrono>
#include <map>
#include <set>
#include <vector>
#include <cmath>

using namespace godot;

void PolyphonyDetector::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_model", "path"), &PolyphonyDetector::load_model);
    ClassDB::bind_method(D_METHOD("is_loaded"), &PolyphonyDetector::is_loaded);
    ClassDB::bind_method(D_METHOD("detect_samples", "samples", "sample_rate"), &PolyphonyDetector::detect_samples);
    ClassDB::bind_method(D_METHOD("set_thresholds", "onset_thresh", "frame_thresh", "min_note_ms"),
                         &PolyphonyDetector::set_thresholds);
}

PolyphonyDetector::PolyphonyDetector() {
    _env = std::make_unique<Ort::Env>(ORT_LOGGING_LEVEL_WARNING, "polyphony");
}
PolyphonyDetector::~PolyphonyDetector() {}

void PolyphonyDetector::set_thresholds(float onset_thresh, float frame_thresh, float min_note_ms) {
    _onset_thresh = onset_thresh;
    _frame_thresh = frame_thresh;
    _min_note_ms = min_note_ms;
}

bool PolyphonyDetector::is_loaded() const { return _loaded; }

bool PolyphonyDetector::load_model(const String &path) {
    std::string p = path.utf8().get_data();
    try {
        Ort::SessionOptions opts;
        opts.SetIntraOpNumThreads(1);
        opts.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
        // ORT path type is platform-dependent: wchar_t* on Windows, char* elsewhere.
#ifdef _WIN32
        std::wstring wp(p.begin(), p.end());
        _session = std::make_unique<Ort::Session>(*_env, wp.c_str(), opts);
#else
        _session = std::make_unique<Ort::Session>(*_env, p.c_str(), opts);
#endif
        _loaded = true;
    } catch (const std::exception &e) {
        UtilityFunctions::push_error(String("PolyphonyDetector load failed: ") + e.what());
        _loaded = false;
    }
    return _loaded;
}

Dictionary PolyphonyDetector::detect_samples(const PackedFloat32Array &samples, int sample_rate) {
    Dictionary out;
    if (!_loaded) { out["error"] = "model not loaded"; return out; }
    if (samples.size() == 0) { out["error"] = "empty samples"; return out; }

    // 1. Preprocess: resample -> 22050, window.
    std::vector<float> mono(samples.ptr(), samples.ptr() + samples.size());
    std::vector<float> audio = poly::resample_to_22050(mono.data(), mono.size(), sample_rate);
    int n_windows = 0, orig_len = 0;
    std::vector<float> input = poly::window_audio(audio, n_windows, orig_len);
    int n_times = poly::n_output_frames(orig_len);
    if (n_times <= 0) { out["error"] = "audio too short"; return out; }

    // 2. Inference.
    auto t0 = std::chrono::high_resolution_clock::now();
    Ort::MemoryInfo mem = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    std::vector<int64_t> in_shape = { (int64_t)n_windows, poly::AUDIO_N_SAMPLES, 1 };
    Ort::Value in_t = Ort::Value::CreateTensor<float>(mem, input.data(), input.size(),
                                                      in_shape.data(), in_shape.size());
    const char *in_names[] = { "serving_default_input_2:0" };
    const char *out_names[] = { "StatefulPartitionedCall:2", "StatefulPartitionedCall:1" }; // onset, note
    std::vector<Ort::Value> outs;
    try {
        outs = _session->Run(Ort::RunOptions{ nullptr }, in_names, &in_t, 1, out_names, 2);
    } catch (const std::exception &e) {
        out["error"] = String("inference failed: ") + e.what();
        return out;
    }

    auto info = outs[1].GetTensorTypeAndShapeInfo();
    auto shp = info.GetShape();                 // [n_windows, fpw, 88]
    int fpw = (int)shp[1];
    int n_freq = (int)shp[2];
    float *onset_raw = outs[0].GetTensorMutableData<float>();
    float *note_raw = outs[1].GetTensorMutableData<float>();
    std::vector<float> onset_v(onset_raw, onset_raw + (size_t)n_windows * fpw * n_freq);
    std::vector<float> note_v(note_raw, note_raw + (size_t)n_windows * fpw * n_freq);

    poly::Mat onset = poly::unwrap_output(onset_v, n_windows, fpw, n_freq, poly::N_OVERLAPPING_FRAMES, n_times);
    poly::Mat note = poly::unwrap_output(note_v, n_windows, fpw, n_freq, poly::N_OVERLAPPING_FRAMES, n_times);

    // 3. Postprocess -> note events.
    int min_note_len = (int)std::lround(_min_note_ms / 1000.0f * (22050.0f / poly::FFT_HOP));
    auto events = poly::output_to_notes_polyphonic(note, onset, _onset_thresh, _frame_thresh, min_note_len);
    auto t1 = std::chrono::high_resolution_clock::now();
    double infer_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

    // 4. Filter (duration + amplitude) + octave-ghost removal — matches the sidecar.
    const float sec_per_frame = (float)poly::FFT_HOP / 22050.0f;
    std::map<int, float> amp; // midi -> max amplitude
    for (auto &e : events) {
        float dur_s = (e.end - e.start) * sec_per_frame;
        if (dur_s >= _min_dur_s && e.amplitude >= _min_amp)
            amp[e.midi] = std::max(amp.count(e.midi) ? amp[e.midi] : 0.0f, e.amplitude);
    }
    // octave-ghost filter: drop a note much quieter than a same-PC neighbour
    std::map<int, float> pc_loudest;
    for (auto &kv : amp) pc_loudest[kv.first % 12] = std::max(pc_loudest[kv.first % 12], kv.second);
    PackedInt32Array notes, all_detected;
    std::set<int> pcs;
    for (auto &kv : amp) {
        all_detected.push_back(kv.first);
        if (kv.second >= _ghost_amp_frac * pc_loudest[kv.first % 12]) {
            notes.push_back(kv.first);
            pcs.insert(kv.first % 12);
        }
    }
    PackedInt32Array pitch_classes;
    for (int pc : pcs) pitch_classes.push_back(pc);

    out["notes"] = notes;
    out["pitch_classes"] = pitch_classes;
    out["all_detected"] = all_detected;
    out["infer_ms"] = (float)infer_ms;
    out["n_windows"] = n_windows;
    return out;
}
