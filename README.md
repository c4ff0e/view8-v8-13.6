# view8-13

V8 bytecode decompiler for V8 13.6 (Electron 36 / Chromium 136).

Based on [View8](https://github.com/suleram/View8) and [v8dasm](https://github.com/noelex/v8dasm).

## Build

```bash
# 1. Get V8 source
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
fetch v8
cd v8 && git checkout 13.6.233.8 && gclient sync
cd ..

# 2. Modify V8 source — add bytecode dump hook in src/snapshot/code-serializer.cc
# See v8dasm docs for details: https://github.com/noelex/v8dasm

# 3. Build V8
gn gen v8/out/disasm --args='
    is_debug = false
    target_cpu = "x64"
    v8_static_library = true
    v8_monolithic = true
    v8_enable_disassembler = true
    v8_enable_object_print = true
    v8_enable_pointer_compression = true
    v8_enable_sandbox = true
    use_sysroot = false
'
ninja -C v8/out/disasm v8_monolith

# 4. Build disasm
bash build.sh disasm
```

## Usage

```bash
./disasm file.jsc > bytecode.dump 2>log.txt
```

Feed to [View8](https://github.com/suleram/View8) for decompilation.
