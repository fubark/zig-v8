# zig-v8

Builds V8 from official source and provides C bindings and a Zig API. This would be used for embedding the V8 runtime into your Zig or C ABI compatible projects.

## Project Status
V8 is complex and although the build steps provided helps, there may be edge cases you'll have to deal with. Submit a ticket or pull request if that happens.

| Status | Platform | Size (demo.zig)* |
| ------ | -------- | -------- |
| ✅ | Linux x64 | TBD |
| Not yet | Windows x64 | TBD |
| Not yet | macOS x64 | TBD |
| Not yet | macOS arm64 | TBD |

\* We'll add a size metric for an embedded V8 demo binary once we get the build to work on more platforms.

## Build
uild times can be quite long but afterwards rerunning "zig build" should be incremental.

```sh
# Clone the repo.
git clone https://github.com/fubark/zig-v8.git

# Pull submodules.
cd zig-v8
git submodule update --init --recursive

# Pull v8 source
zig build get-v8

# Pull prebuilt GN/Ninja.
zig build get-tools

# Build, resulting static library should be at:
# v8-out/ninja/obj/zig/libc_v8.a
zig build
```

## Usage

See test/test.zig on how to use the library with the Zig API as well as build.zig (fn createTest) on how to link with the V8 static library.

## Contributing

The C bindings is incomplete but it should be relatively easy to add more as we need them.

C API naming convention should closely follow the V8 C++ API.
