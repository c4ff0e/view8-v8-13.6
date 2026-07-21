#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

DEPS="$PWD/depot_tools"
export PATH="$DEPS:$PATH"
CLANG="v8/third_party/llvm-build/Release+Asserts/bin/clang++"
LIBCXX="v8/third_party/libc++/src/include"
LIBCXXABI="v8/third_party/libc++abi/src/include"
LIBCXX_CFG="v8/buildtools/third_party/libc++"
MONOLITH="v8/out/disasm/obj/libv8_monolith.a"
LIBCXX_OBJS="v8/out/disasm/obj/buildtools/third_party/libc++/libc++/*.o"
LIBCXXABI_OBJS="v8/out/disasm/obj/buildtools/third_party/libc++abi/libc++abi/*.o"

CXXFLAGS="-std=c++20 -DV8_COMPRESS_POINTERS -DV8_COMPRESS_POINTERS_IN_SHARED_CAGE -DV8_31BIT_SMIS_ON_64BIT_ARCH -DV8_ENABLE_SANDBOX -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE -I v8/include -I v8 -I v8/out/disasm/gen -I $LIBCXX_CFG -nostdinc++ -isystem $LIBCXX -isystem $LIBCXXABI -fuse-ld=lld"
LIBS="-lpthread -ldl -lrt -lz"

case "${1:-all}" in
    v8)
        cd v8
        ninja -C out/disasm v8_monolith
        cd ..
        ;;
    disasm)
        $CLANG $CXXFLAGS disasm.cpp $MONOLITH $LIBCXX_OBJS $LIBCXXABI_OBJS $LIBS -o disasm
        ls -lh disasm
        ;;
    test)
        cat > /tmp/selftest.cpp << 'CPPEOF'
#include <iostream>
#include <fstream>
#include <libplatform/libplatform.h>
#include <v8.h>
using namespace v8;
static Isolate* isolate = nullptr;
int main() {
    v8::V8::SetFlagsFromString("--no-lazy --no-flush-bytecode");
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
        auto source = String::NewFromUtf8(isolate, "function hello() { return 1+2; }").ToLocalChecked();
        auto script = Script::Compile(ctx, source).ToLocalChecked();
        auto unbound = script->GetUnboundScript();
        auto cached = ScriptCompiler::CreateCodeCache(unbound);
        std::ofstream out("/tmp/selftest.jsc", std::ios::binary);
        out.write((const char*)cached->data, cached->length);
        out.close();
        std::cout << "Created jsc: " << cached->length << " bytes" << std::endl;
        auto cached_data = new ScriptCompiler::CachedData(cached->data, cached->length);
        ScriptOrigin origin(String::NewFromUtf8(isolate, "test.jsc").ToLocalChecked());
        ScriptCompiler::Source src(String::NewFromUtf8(isolate, "function hello() { return 1+2; }").ToLocalChecked(), origin, cached_data);
        auto maybeScript = ScriptCompiler::CompileUnboundScript(isolate, &src, ScriptCompiler::kConsumeCodeCache);
        std::cout << (maybeScript.IsEmpty() ? "FAIL" : "SELF-TEST OK") << std::endl;
    }
    isolate->Dispose(); v8::V8::Dispose(); v8::V8::DisposePlatform();
    delete p.array_buffer_allocator; return 0;
}
CPPEOF
        $CLANG $CXXFLAGS /tmp/selftest.cpp $MONOLITH $LIBCXX_OBJS $LIBCXXABI_OBJS $LIBS -o /tmp/selftest
        /tmp/selftest
        ;;
    run)
        ./disasm /tmp/asar-extract/out/main/index.jsc > index.dump 2>&1
        echo "Lines: $(wc -l < index.dump)"
        head -20 index.dump
        ;;
    all)
        echo "=== V8 ===" && cd v8 && ninja -C out/disasm v8_monolith && cd ..
        echo "=== LINK ===" && $CLANG $CXXFLAGS disasm.cpp $MONOLITH $LIBCXX_OBJS $LIBCXXABI_OBJS $LIBS -o disasm && ls -lh disasm
        echo "=== TEST ===" && bash "$0" test
        echo "=== DONE ==="
        ;;
    *)
        echo "Usage: $0 {v8|disasm|test|run|all}"
        ;;
esac
