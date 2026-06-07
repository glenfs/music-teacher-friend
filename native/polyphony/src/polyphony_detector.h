#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <onnxruntime_cxx_api.h>
#include <memory>

namespace godot {

// Polyphonic note detector — runs Basic Pitch (ONNX) over a recorded take and
// returns every played note. Replaces the Python sidecar on desktop; the same
// code targets Android (Phase D).
//
// GDScript:
//   var d := PolyphonyDetector.new()
//   d.load_model(ProjectSettings.globalize_path("res://addons/polyphony/nmp.onnx"))
//   var r := d.detect_samples(samples, 44100)   # r.notes, r.pitch_classes, r.infer_ms
class PolyphonyDetector : public RefCounted {
    GDCLASS(PolyphonyDetector, RefCounted)

protected:
    static void _bind_methods();

public:
    PolyphonyDetector();
    ~PolyphonyDetector();

    bool load_model(const String &path);
    bool is_loaded() const;

    // Returns { notes:PackedInt32Array, pitch_classes:PackedInt32Array,
    //           all_detected:PackedInt32Array, infer_ms:float, error?:String }
    Dictionary detect_samples(const PackedFloat32Array &samples, int sample_rate);

    // Tuning (defaults match the validated sidecar).
    void set_thresholds(float onset_thresh, float frame_thresh, float min_note_ms);

private:
    std::unique_ptr<Ort::Env> _env;
    std::unique_ptr<Ort::Session> _session;
    bool _loaded = false;

    float _onset_thresh = 0.5f;
    float _frame_thresh = 0.45f;
    float _min_note_ms = 120.0f;
    float _min_dur_s = 0.12f;
    float _min_amp = 0.10f;
    float _ghost_amp_frac = 0.55f;
};

} // namespace godot
