# zig-v8

Builds V8 from official source and provides C bindings and a Zig API. This would be used for embedding the V8 runtime into your Zig or C ABI compatible projects.

V8 is the JS/WASM runtime that powers Google Chrome and Microsoft Edge.

## Project Status
Static libs are built and released with [Github Actions](https://github.com/fubark/zig-v8/actions).
| Native | Cross Compile | Target | Demo Binary ([shell.zig](https://github.com/fubark/zig-v8/blob/master/src/shell.zig))* |
| ------ | ------ | -------- | -------- |
| ✅ | | Linux x64 | shell - 19 M |
| ✅ | ✅ | Windows x64 | shell.exe - 14 M |
| ✅ | | macOS x64 | shell - 24 M |
| ✅ | ✅ | macOS arm64 | shell - 21 M |

\* shell.zig is a JS repl and statically linked with v8. Compiled with -Drelease-safe. The V8 dependency can be further reduced in size if you don't need all the features (eg. disable WASM runtime).

| Toolchain | Fresh Build* | Cached Build* |
| ------ | ------ | ------ |
| gclient, full feature + v8 toolchain | 1.5-2 hrs | with sccache: 10-20min |
| minimal feature + v8 toolchain | 40-50 min | with sccache: 5-10min |
| minimal feature + zig c++ toolchain |  | with zig caching:  |

\* Time is measured on standard Github instances.

## System Requirements
- Zig compiler (0.11.0). You can get that [here](https://ziglang.org/download/).
- Python 3 (2.7 seems to work as well)
- For native macOS builds:
  - XCode (You won't need this when using zig's c++ toolchain!)<br/>
if you come across this error:<br />
`xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`<br />
  run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`

## Build
By default UseGclient=false in build.zig. This will pull the minimum sources and deps needed to build v8 and reduce build times.

If you want to include everything, set UseGclient=true. Build times can be quite long using gclient but afterwards rerunning "zig build" should be incremental. You can also use sccache for better incremental build times.

```sh
# Clone the repo.
git clone https://github.com/fubark/zig-v8.git
cd zig-v8

# Pull prebuilt GN/Ninja. If UseGclient=true, it also pulls depot_tools.
zig build get-tools

# Pull v8 source
zig build get-v8

# Build, resulting static library should be at:
# v8-build/{target}/{debug/release}/ninja/obj/zig/libc_v8.a
# On windows, use msvc: zig build -Drelease-safe -Dtarget=x86_64-windows-msvc
zig build -Drelease-safe
```
## Demo
```sh
# shell.zig is a simple JS repl.
# Assumes you've already built v8.
zig build run -Dpath="src/shell.zig" -Drelease-safe

# If you built v8 using the zig toolchain, you'll need to add the flag here as well.
zig build run -Dpath="src/shell.zig" -Drelease-safe -Dzig-toolchain
```

## Cross Compiling
With Zig's toolchain, we can build V8 from libstdc++ that's bundled with zig and cross compile to foreign targets/cpus! Simply amazing. Eventually, this will also replace the default V8 toolchain for native builds after further testing.
### Linux x64 (Host) to MacOS arm64 (Target)
```sh
# Assumes you've fetched tools and v8 sources. See above build steps.
# Resulting static lib will be at:
# v8-build/aarch64-macos/release/ninja/obj/zig/libc_v8.a
zig build -Drelease-safe -Dtarget=aarch64-macos-gnu -Dzig-toolchain
```

### Cross compile to Windows with gnu (mingw64)
Zig comes with mingw64 source and headers so you'll be able to target Windows without MSVC.
```sh
zig build -Drelease-safe -Dtarget=x86_64-windows-gnu -Dzig-toolchain
```

## Usage

See src/shell.zig or test/test.zig on how to use the library with the Zig API as well as build.zig (fn linkV8) on how to link with the built V8 static library.

## Contributing

The C bindings is incomplete but it should be relatively easy to add more as we need them.

C API naming convention should closely follow the V8 C++ API.
