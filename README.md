# zig-v8

Builds V8 from official source and provides C bindings and a Zig API. This would be used for embedding the V8 runtime into your Zig or C ABI compatible projects.

V8 is the JS/WASM runtime that powers Google Chrome and Microsoft Edge.

## Project Status
Static libs are built and released with [Github Actions](https://github.com/fubark/zig-v8/actions).
| Status | Platform | Demo Binary ([shell.zig](https://github.com/fubark/zig-v8/blob/master/src/shell.zig))* |
| ------ | -------- | -------- |
| ✅ | Linux x64 | shell - 19 M |
| ✅ | Windows x64 | shell.exe - 12 M |
| ✅ | macOS x64 | shell - 24 M |
| Soon | macOS arm64 | TBD |

\* shell.zig is a JS repl and statically linked with v8. Compiled with -Drelease-safe. The V8 dependency can be further reduced in size if you don't need all the features (eg. disable WASM runtime).

## Build
You'll need the Zig compiler (0.9.0). You can get that [here](https://ziglang.org/download/).

By default UseGclient=false in build.zig. This will pull the minimum sources and deps needed to build v8 and reduce build times.

If you want to include everything, set UseGclient=true. Build times can be quite long using gclient but afterwards rerunning "zig build" should be incremental. You can also use sccache for better incremental build times.

```sh
# Clone the repo.
git clone https://github.com/fubark/zig-v8.git
cd zig-v8

# You'll need python 3 installed on your machine.
# Pull prebuilt GN/Ninja. If UseGclient=true, it also pulls depot_tools.
zig build get-tools

# Pull v8 source
zig build get-v8

# Build, resulting static library should be at:
# v8-out/{target}/{debug/release}/ninja/obj/zig/libc_v8.a
# On windows, use msvc: zig build -Drelease-safe -Dtarget=x86_64-windows-msvc
zig build -Drelease-safe
```
## Demo
```sh
# shell.zig is a simple JS repl.
# Assumes you've already built v8.
zig build run -Dpath="src/shell.zig" -Drelease-safe
```

## Usage

See src/shell.zig or test/test.zig on how to use the library with the Zig API as well as build.zig (fn linkV8) on how to link with the built V8 static library.

## Contributing

The C bindings is incomplete but it should be relatively easy to add more as we need them.

C API naming convention should closely follow the V8 C++ API.
