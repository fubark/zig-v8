# zig-v8

Builds V8 from official source and provides C bindings and a Zig API. This would be used for embedding the V8 runtime into your Zig or C ABI compatible projects.

## Project Status

| Status | Platform | Size (demo.zig)* |
| ------ | -------- | -------- |
| ✅ | Linux x64 | TBD |
| ✅ | Windows x64 | TBD |
| ✅ | macOS x64 | TBD |
| Soon | macOS arm64 | TBD |

\* We'll add a size metric for an embedded V8 demo binary once we get the build to work on more platforms.

## Build
By default UseGclient=false in build.zig. This will pull the minimum sources and deps needed to build v8 and reduce build times.
If you want to include everything, set UseGclient=true. Build times can be quite long but afterwards rerunning "zig build" should be incremental. You can also use sccache for better incremental build times.

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
zig build
```

## Usage

See test/test.zig on how to use the library with the Zig API as well as build.zig (fn createTest) on how to link with the built V8 static library.

## Contributing

The C bindings is incomplete but it should be relatively easy to add more as we need them.

C API naming convention should closely follow the V8 C++ API.
