// Phase A: prove ONNX Runtime runs the basic-pitch model in C++ on this machine,
// numerically matching the Python reference. NOT part of the GDExtension yet —
// it's the foundational de-risk before wrapping ORT in godot-cpp.
//
// Loads models/nmp.onnx, feeds testdata/<name>.input.bin, runs inference, and
// compares each output tensor against the Python-dumped testdata/<name>.*.bin.
//
// Usage: standalone_parity <polyphony_dir> [name]

#include <onnxruntime_cxx_api.h>

#include <cstdio>
#include <string>
#include <vector>
#include <fstream>
#include <cmath>
#include <algorithm>

static std::vector<float> read_bin(const std::string& path) {
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if (!f) { std::fprintf(stderr, "cannot open %s\n", path.c_str()); return {}; }
    std::streamsize n = f.tellg();
    f.seekg(0, std::ios::beg);
    std::vector<float> v(n / sizeof(float));
    f.read(reinterpret_cast<char*>(v.data()), n);
    return v;
}

static std::wstring widen(const std::string& s) {
    return std::wstring(s.begin(), s.end());
}

int main(int argc, char** argv) {
    std::string base = (argc > 1) ? argv[1] : ".";
    std::string name = (argc > 2) ? argv[2] : "C_major_(C4)";
    std::string model = base + "/models/nmp.onnx";
    std::string td = base + "/testdata/";

    // --- Input ---
    std::vector<float> input = read_bin(td + name + ".input.bin");
    if (input.empty()) return 2;
    const int64_t AUDIO_N = 43844;
    int64_t n_win = static_cast<int64_t>(input.size()) / AUDIO_N;
    std::vector<int64_t> in_shape = { n_win, AUDIO_N, 1 };
    std::printf("input: %lld windows x %lld samples\n", (long long)n_win, (long long)AUDIO_N);

    // --- ORT session ---
    Ort::Env env(ORT_LOGGING_LEVEL_WARNING, "poly");
    Ort::SessionOptions opts;
    opts.SetIntraOpNumThreads(1);
    opts.SetGraphOptimizationLevel(GraphOptimizationLevel::ORT_ENABLE_ALL);
    Ort::Session session(env, widen(model).c_str(), opts);

    Ort::MemoryInfo mem = Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault);
    Ort::Value in_tensor = Ort::Value::CreateTensor<float>(
        mem, input.data(), input.size(), in_shape.data(), in_shape.size());

    const char* in_names[] = { "serving_default_input_2:0" };
    const char* out_names[] = { "StatefulPartitionedCall:2",   // note/onset (88)
                                "StatefulPartitionedCall:1",   // note/onset (88)
                                "StatefulPartitionedCall:0" }; // contour (264)

    auto outs = session.Run(Ort::RunOptions{ nullptr }, in_names, &in_tensor, 1, out_names, 3);

    // --- Compare each output to the Python dump ---
    const char* ref_files[] = {
        ".StatefulPartitionedCall_2.bin",
        ".StatefulPartitionedCall_1.bin",
        ".StatefulPartitionedCall_0.bin" };

    bool all_ok = true;
    double worst = 0.0;
    for (int i = 0; i < 3; ++i) {
        float* data = outs[i].GetTensorMutableData<float>();
        auto info = outs[i].GetTensorTypeAndShapeInfo();
        size_t count = info.GetElementCount();
        std::vector<float> ref = read_bin(td + name + ref_files[i]);
        if (ref.size() != count) {
            std::printf("  out %d: SIZE MISMATCH cpp=%zu ref=%zu\n", i, count, ref.size());
            all_ok = false;
            continue;
        }
        double max_abs = 0.0;
        for (size_t k = 0; k < count; ++k)
            max_abs = std::max(max_abs, std::fabs((double)data[k] - (double)ref[k]));
        worst = std::max(worst, max_abs);
        std::printf("  out %d (%s): %zu elems, max|diff|=%.3e %s\n",
                    i, out_names[i], count, max_abs, (max_abs < 1e-4 ? "OK" : "MISMATCH"));
        if (max_abs >= 1e-4) all_ok = false;
    }

    std::printf("PARITY %s (worst max|diff|=%.3e)\n", all_ok ? "PASS" : "FAIL", worst);
    return all_ok ? 0 : 1;
}
