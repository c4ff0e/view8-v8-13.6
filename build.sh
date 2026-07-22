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

DEFINES="-DV8_COMPRESS_POINTERS -DV8_COMPRESS_POINTERS_IN_SHARED_CAGE -DV8_31BIT_SMIS_ON_64BIT_ARCH -DV8_ENABLE_SANDBOX"
CXXFLAGS="-std=c++20 $DEFINES -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE -I v8/include -I v8 -I v8/out/disasm/gen -I $LIBCXX_CFG -nostdinc++ -isystem $LIBCXX -isystem $LIBCXXABI -fuse-ld=lld"
LIBS="-lpthread -ldl -lrt -lz"

case "${1:-all}" in
    v8)
        cd v8 && ninja -C out/disasm v8_monolith && cd ..
        ;;
    disasm)
        $CLANG $CXXFLAGS disasm.cpp $MONOLITH $LIBCXX_OBJS $LIBCXXABI_OBJS $LIBS -o disasm
        ls -lh disasm
        ;;
    all)
        echo "=== V8 ===" && cd v8 && ninja -C out/disasm v8_monolith && cd ..
        echo "=== LINK ===" && $CLANG $CXXFLAGS disasm.cpp $MONOLITH $LIBCXX_OBJS $LIBCXXABI_OBJS $LIBS -o disasm && ls -lh disasm
        ;;
    *)
        echo "Usage: $0 {v8|disasm|all}"
        ;;
esac
