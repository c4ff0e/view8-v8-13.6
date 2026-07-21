# view8-13

V8 bytecode decompiler for V8 13.6.

Based on [View8](https://github.com/suleram/View8) and [v8dasm](https://github.com/noelex/v8dasm).

## Build

```bash
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH="$PWD/depot_tools:$PATH"
fetch v8
cd v8 && git checkout 13.6.233.8 && gclient sync
cd ..

# Apply patches to v8/src/snapshot/code-serializer.cc
# and v8/src/diagnostics/objects-printer.cc (see v8dasm docs)

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
bash build.sh disasm
```

## Usage

```bash
./disasm file.jsc > file.dump
```

Feed `file.dump` to [View8](https://github.com/suleram/View8) for decompilation.
