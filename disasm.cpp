// disasm.cpp — загрузчик jsc для V8 13.6 под Linux
// Основан на v8dasm.cpp (noelex/v8dasm), адаптирован под Linux/V8 13.6

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <cstring>

#include <libplatform/libplatform.h>
#include <v8.h>

using namespace v8;

static Isolate* isolate = nullptr;

static void readAllBytes(const std::string& file, std::vector<char> &buffer) {
    std::ifstream infile(file, std::ifstream::binary);
    infile.seekg(0, infile.end);
    size_t length = infile.tellg();
    infile.seekg(0, infile.beg);
    if (length > 0) {
        buffer.resize(length);
        infile.read(&buffer[0], length);
    }
}

static uint32_t readSourceHash(uint8_t* data) {
    return data[8] | (data[9] << 8) | (data[10] << 16) | (data[11] << 24);
}

static std::string makeDummySource(uint32_t length) {
    std::string s = "\"";
    for (uint32_t i = 0; i < length - 2; i++) {
        s += "\xE2\x80\x8B";  // U+200B zero-width space (UTF-8)
    }
    s += "\"";
    return s;
}

static ScriptCompiler::CachedData* compileDummy(const std::string& code) {
    auto str = String::NewFromUtf8(isolate, code.c_str()).ToLocalChecked();
    auto ctx = isolate->GetCurrentContext();
    auto script = Script::Compile(ctx, str).ToLocalChecked();
    return ScriptCompiler::CreateCodeCache(script->GetUnboundScript());
}

static void fixBytecode(uint8_t* bytecodeBuffer, const std::string& dummyCode) {
    auto dummy = compileDummy(dummyCode);
    // Copy: magic (0-3), version hash (4-7), flag hash (12-15), ro_snapshot_checksum (16-19)
    // Keep ORIGINAL: source hash (8-11), payload length (20-23)
    for (int i = 0; i < 8; i++)    bytecodeBuffer[i] = dummy->data[i];     // 0-7: magic + version hash
    // 8-11: source hash — KEEP ORIGINAL
    for (int i = 12; i < 20; i++)  bytecodeBuffer[i] = dummy->data[i];    // 12-19: flag hash + ro_snapshot_checksum
    // 20-23: payload length — KEEP ORIGINAL
    delete dummy;
}

static void loadAndDisassemble(uint8_t* bytecodeBuffer, int len) {
    uint32_t sourceLen = readSourceHash(bytecodeBuffer);
    std::cerr << "[disasm] source hash: " << sourceLen << " bytes" << std::endl;

    // Create dummy source of correct length (same trick as bytecode-loader.cjs)
    std::string dummyCode = sourceLen > 1
        ? makeDummySource(sourceLen)
        : "\"ಠ_ಠ\"";

    if (sourceLen > 1) {
        std::cerr << "[disasm] created dummy source: " << dummyCode.length() << " chars" << std::endl;
    }

    fixBytecode(bytecodeBuffer, dummyCode);

    auto cached_data = new ScriptCompiler::CachedData(bytecodeBuffer, len);
    auto ctx = isolate->GetCurrentContext();
    ScriptOrigin origin(String::NewFromUtf8(isolate, "code.jsc").ToLocalChecked());
    ScriptCompiler::Source source(
        String::NewFromUtf8(isolate, dummyCode.c_str()).ToLocalChecked(),
        origin,
        cached_data
    );

    auto maybeScript = ScriptCompiler::CompileUnboundScript(
        isolate, &source, ScriptCompiler::kConsumeCodeCache
    );

    if (maybeScript.IsEmpty()) {
        std::cerr << "[disasm] ERROR: failed to compile from code cache" << std::endl;
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: disasm <file.jsc>" << std::endl;
        return 1;
    }

    v8::V8::SetFlagsFromString("--no-lazy --no-flush-bytecode --profile-deserialization");

    v8::V8::InitializeICU();
    auto plat = v8::platform::NewDefaultPlatform();
    v8::V8::InitializePlatform(plat.get());
    v8::V8::Initialize();

    Isolate::CreateParams p = {};
    p.array_buffer_allocator = ArrayBuffer::Allocator::NewDefaultAllocator();
    isolate = Isolate::New(p);

    {
        HandleScope scope(isolate);
        auto ctx = Context::New(isolate);
        Context::Scope context_scope(ctx);

        std::vector<char> data;
        readAllBytes(argv[1], data);
        loadAndDisassemble((uint8_t*)data.data(), data.size());
    }

    isolate->Dispose();
    v8::V8::Dispose();
    v8::V8::DisposePlatform();
    delete p.array_buffer_allocator;
    return 0;
}
