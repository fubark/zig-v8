const std = @import("std");
const json = std.json;
const Builder = std.Build;
const Step = std.Build.Step;
const print = std.debug.print;
const builtin = @import("builtin");
const Pkg = std.build.Pkg;

const fs = std.fs;

pub fn build(b: *Builder) !void {
    // Options.
    //const build_v8 = b.option(bool, "build_v8", "Whether to build from v8 source") orelse false;
    const path = b.option([]const u8, "path", "Path to main file, for: build, run") orelse "";
    const use_zig_tc = b.option(bool, "zig-toolchain", "Experimental: Use zig cc/c++/ld to build v8.") orelse false;

    const mode = b.standardOptimizeOption(.{}); //FIXED
    const target = b.standardTargetOptions(.{});

    _ = createGetTools(b);
    _ = createGetV8(b);

    const v8 = try createV8_Build(b, target, mode, use_zig_tc);

    const tests = createTest(b, target, mode, use_zig_tc);
    tests.step.dependOn(v8);

    const test_step = b.addRunArtifact(tests);
    b.step("test", "Run unit tests").dependOn(&test_step.step);

    const build_exe = createBuildExeStep(b, path, target, mode, use_zig_tc);

    const run_exe = b.addRunArtifact(build_exe);
    b.step("run", "Run with main file at -Dpath").dependOn(&run_exe.step);

    b.default_step.dependOn(v8);
}

// When this is true, we'll strip V8 features down to a minimum so the resulting library is smaller.
// eg. i18n will be excluded.
const MinimalV8 = true;

// gclient is comprehensive and will pull everything for the v8 project.
// Set this to false to pull the minimal required src by parsing v8/DEPS and whitelisting deps we care about.
const UseGclient = false;

// V8's build process is complex and porting it to zig could take quite awhile.
// It would be nice if there was a way to import .gn files into the zig build system.
// For now we just use gn/ninja like rusty_v8 does: https://github.com/denoland/rusty_v8/blob/main/build.rs
fn createV8_Build(b: *Builder, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode, use_zig_tc: bool) !*std.Build.Step {
    const step = b.step("v8", "Build v8 c binding lib.");

    if (UseGclient) {
        const mkpath = MakePathStep.create(b, "./gclient/v8/zig");
        step.dependOn(&mkpath.step);

        const cp = CopyFileStep.create(b, b.pathFromRoot("BUILD.gclient.gn"), b.pathFromRoot("gclient/v8/zig/BUILD.gn"));
        step.dependOn(&cp.step);
    } else {
        const mkpath = MakePathStep.create(b, "./v8/zig");
        step.dependOn(&mkpath.step);

        const cp = CopyFileStep.create(b, b.pathFromRoot("BUILD.gn"), b.pathFromRoot("v8/zig/BUILD.gn"));
        step.dependOn(&cp.step);
    }

    var gn_args = std.ArrayList([]const u8).init(b.allocator);

    switch (target.result.os.tag) {
        .macos => try gn_args.append("target_os=\"mac\""),
        .windows => {
            try gn_args.append("target_os=\"win\"");
            if (!UseGclient) {
                // Don't use depot_tools.
                try b.graph.env_map.put("DEPOT_TOOLS_WIN_TOOLCHAIN", "0");
            }
        },
        .linux => try gn_args.append("target_os=\"linux\""),
        else => {},
    }
    switch (target.result.cpu.arch) {
        .x86_64 => try gn_args.append("target_cpu=\"x64\""),
        .aarch64 => try gn_args.append("target_cpu=\"arm64\""),
        else => {},
    }

    var zig_cc = std.ArrayList([]const u8).init(b.allocator);
    var zig_cxx = std.ArrayList([]const u8).init(b.allocator);
    var host_zig_cc = std.ArrayList([]const u8).init(b.allocator);
    var host_zig_cxx = std.ArrayList([]const u8).init(b.allocator);

    if (mode == .Debug) {
        try gn_args.append("is_debug=true");
        // full debug info (symbol_level=2).
        // Setting symbol_level=1 will produce enough information for stack traces, but not line-by-line debugging.
        // Setting symbol_level=0 will include no debug symbols at all. Either will speed up the build compared to full symbols.
        // This will eventually pass down to v8_symbol_level.
        try gn_args.append("symbol_level=1");
    } else {
        try gn_args.append("is_debug=false");
        try gn_args.append("symbol_level=0");

        // is_official_build is meant to ship chrome.
        // It might be interesting to see how far we can get with it (previously saw illegal instruction in Zone::NewExpand during mksnapshot_default since stacktraces were removed)
        // but a better approach for now is to set to false and slowly enable optimizations. eg. We probably still want to unwind stack traces.
        try gn_args.append("is_official_build=false");
        // is_official_build will do pgo optimization by default for chrome specific builds that require gclient to fetch profile data.
        // https://groups.google.com/a/chromium.org/g/chromium-dev/c/-0t4s0RlmOI
        // Disable that with this:
        //try gn_args.append("chrome_pgo_phase=0");
        //if (use_zig_tc) {
        // is_official_build will enable cfi but zig does not come with the default cfi_ignorelist.
        //try zig_cppflags.append("-fno-sanitize-ignorelist");
        //}

        // TODO: Might want to turn V8_ENABLE_CHECKS off to remove asserts.
    }

    if (MinimalV8) {
        // Don't add i18n for now. It has a large dependency on third_party/icu.
        try gn_args.append("v8_enable_i18n_support=false");
    }

    if (mode != .Debug) {
        // TODO: document
        try gn_args.append("v8_enable_handle_zapping=false");
    }

    // Fix GN's host_cpu detection when using x86_64 bins on Apple Silicon
    if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
        try gn_args.append("host_cpu=\"arm64\"");
    }

    if (use_zig_tc) {
        // Set target and cpu for building the lib.
        // TODO: If mcpu is equavalent to -Dcpu then use that instead
        try zig_cc.append(b.fmt("zig cc --target={s} -mcpu=baseline", .{try target.result.zigTriple(b.allocator)}));
        try zig_cxx.append(b.fmt("zig c++ --target={s} -mcpu=baseline", .{try target.result.zigTriple(b.allocator)}));

        try host_zig_cc.append("zig cc --target=native");
        try host_zig_cxx.append("zig c++ --target=native");

        // Ignore "a function definition without a prototype is deprecated in all versions of C and is not supported in C2x [-Werror,-Wdeprecated-non-prototype]"
        try zig_cc.append("-Wno-deprecated-non-prototype");
        try zig_cxx.append("-Wno-deprecated-non-prototype");
        try host_zig_cc.append("-Wno-deprecated-non-prototype");
        try host_zig_cxx.append("-Wno-deprecated-non-prototype");

        // For zlib.
        try zig_cc.append("-mcrc32");
        try zig_cxx.append("-mcrc32");

        if (target.result.os.tag == .windows and target.result.abi == .gnu) {
            // V8 expects __declspec(dllexport) to not expand in it's test in src/base/export-template.h but it does when compiling with mingw.
            try zig_cxx.append("-DEXPORT_TEMPLATE_TEST_MSVC_HACK_DEFAULT\\(...\\)=true");
        }
        if (target.result.os.tag == .windows and builtin.os.tag != .windows) {
            // Cross building to windows probably is case sensitive to header files, so provide them in include.
            // Note: Directory is relative to ninja build folder.
            try zig_cxx.append("-I../../../../cross-windows");

            // Make src/base/bits.h include win32-headers.h
            try zig_cxx.append("-DV8_OS_WIN32=1");

            // Use wchar_t unicode functions.
            try zig_cxx.append("-DUNICODE=1");

            // clang doesn't seem to recognize guard(nocf) even with -fdeclspec. It might be because mingw has a macro for __declspec.
            try zig_cxx.append("-Wno-error=unknown-attributes");

            // include/v8config.h doesn't set mingw flags if __clang__ is defined.
            try zig_cxx.append("-DV8_CC_MINGW32=1");
            try zig_cxx.append("-DV8_CC_MINGW64=1");
            try zig_cxx.append("-DV8_CC_MINGW=1");

            // Windows version. See build/config/win/BUILD.gn
            try zig_cxx.append("-DNTDDI_VERSION=NTDDI_WIN10_VB");
            try zig_cxx.append("-D_WIN32_WINNT=0x0A00");
            try zig_cxx.append("-DWINVER=0x0A00");

            // Enable support for MSVC pragmas.
            try zig_cxx.append("-fms-extensions");

            // Disable instrumentation since mingw doesn't have TraceLoggingProvider.h
            try gn_args.append("v8_enable_system_instrumentation=false");
            try gn_args.append("v8_enable_etw_stack_walking=false");
        }

        // Use zig's libcxx instead.
        // If there are problems we can see what types of flags are enabled when this is true.
        try gn_args.append("use_custom_libcxx=false");

        // custom_toolchain is how we can set zig as the cc/cxx compiler and linker.
        try gn_args.append("custom_toolchain=\"//zig:main_zig_toolchain\"");

        if (target.result.os.tag == .linux and target.result.cpu.arch == .x86_64) {
            // Should add target flags that matches: //build/config/compiler:compiler_cpu_abi
            try zig_cc.append("-m64");
            try zig_cxx.append("-m64");
        } else if (target.result.os.tag == .macos) {
            if (!target.query.isNative()) {
                // Cross compiling.
                const sysroot_abs = b.pathFromRoot("./cross-macos/sysroot/macos-12/usr/include");
                try zig_cc.append("-isystem");
                try zig_cc.append(sysroot_abs);
                try zig_cxx.append("-isystem");
                try zig_cxx.append(sysroot_abs);
            }
        }
        if (builtin.cpu.arch != target.result.cpu.arch or builtin.os.tag != target.result.os.tag) {
            try gn_args.append("v8_snapshot_toolchain=\"//zig:v8_zig_toolchain\"");
        }

        // Just warn for now. TODO: Check to remove after next clang update.
        // https://bugs.chromium.org/p/chromium/issues/detail?id=1016945
        try zig_cxx.append("-Wno-error=builtin-assume-aligned-alignment");
        try host_zig_cxx.append("-Wno-error=builtin-assume-aligned-alignment");

        try gn_args.append("use_zig_tc=true");
        try gn_args.append("cxx_use_ld=\"zig ld.lld\"");

        // Build zig cc strings.
        var arg = b.fmt("zig_cc=\"{s}\"", .{try std.mem.join(b.allocator, " ", zig_cc.items)});
        try gn_args.append(arg);
        arg = b.fmt("zig_cxx=\"{s}\"", .{try std.mem.join(b.allocator, " ", zig_cxx.items)});
        try gn_args.append(arg);
        arg = b.fmt("host_zig_cc=\"{s}\"", .{try std.mem.join(b.allocator, " ", host_zig_cc.items)});
        try gn_args.append(arg);
        arg = b.fmt("host_zig_cxx=\"{s}\"", .{try std.mem.join(b.allocator, " ", host_zig_cxx.items)});
        try gn_args.append(arg);
    } else {
        if (builtin.os.tag != .windows) {
            try gn_args.append("cxx_use_ld=\"lld\"");
        }
    }

    // sccache, currently does not work with zig cc
    if (!use_zig_tc) {
        if (b.graph.env_map.get("SCCACHE")) |path| {
            const cc_wrapper = try std.fmt.allocPrint(b.allocator, "cc_wrapper=\"{s}\"", .{path});
            try gn_args.append(cc_wrapper);
        } else {
            if (builtin.os.tag == .windows) {
                // findProgram look for "PATH" case sensitive.
                try b.graph.env_map.put("PATH", b.graph.env_map.get("Path") orelse "");
            }
            if (b.findProgram(&.{"sccache"}, &.{})) |_| {
                const cc_wrapper = try std.fmt.allocPrint(b.allocator, "cc_wrapper=\"{s}\"", .{"sccache"});
                try gn_args.append(cc_wrapper);
            } else |err| {
                if (err != error.FileNotFound) {
                    unreachable;
                }
            }
            if (builtin.os.tag == .windows) {
                // After creating PATH for windows so findProgram can find sccache, we need to delete it
                // or a gn tool (build/toolchain/win/setup_toolchain.py) will complain about not finding cl.exe.
                b.graph.env_map.remove("PATH");
            }
        }
    }

    // var check_deps = CheckV8DepsStep.create(b);
    // step.step.dependOn(&check_deps.step);

    const mode_str: []const u8 = if (mode == .Debug) "debug" else "release";
    // GN will generate ninja build files in ninja_out_path which will also contain the artifacts after running ninja.
    const ninja_out_path = try std.fmt.allocPrint(b.allocator, "v8-build/{s}/{s}/ninja", .{
        getTargetId(b.allocator, target),
        mode_str,
    });

    const gn = getGnPath(b);
    const arg_items = try std.mem.join(b.allocator, " ", gn_args.items);
    const args = try std.mem.join(b.allocator, "", &.{ "--args=", arg_items });
    // Currently we have to use gclient/v8 as the source root since all those nested gn files expects it, (otherwise, we'll run into duplicate argument declaration errors.)
    // --dotfile lets us use a different .gn outside of the source root.
    // --root-target is a directory that must be inside the source root where we can have a custom BUILD.gn.
    //      Since gclient/v8 is not part of our repo, we copy over BUILD.gn to gclient/v8/zig/BUILD.gn before we run gn.
    // To see v8 dependency tree:
    // cd gclient/v8 && gn desc ../../v8-build/x86_64-linux/release/ninja/ :v8 --tree
    // We can't see our own config because gn desc doesn't accept a --root-target.
    // One idea is to append our BUILD.gn to the v8 BUILD.gn instead of putting it in a subdirectory.
    if (UseGclient) {
        var run_gn = b.addSystemCommand(&.{ gn, "--root=gclient/v8", "--root-target=//zig", "--dotfile=.gn", "gen", ninja_out_path, args });
        step.dependOn(&run_gn.step);
    } else {
        // To see available args for gn: cd v8 && gn args --list ../v8-build/{target}/release/ninja/
        var run_gn = b.addSystemCommand(&.{ gn, "--root=v8", "--root-target=//zig", "--dotfile=.gn", "gen", ninja_out_path, args });
        step.dependOn(&run_gn.step);
    }

    const ninja = getNinjaPath(b);
    // Only build our target. If no target is specified, ninja will build all the targets which includes developer tools, tests, etc.
    var run_ninja = b.addSystemCommand(&.{ ninja, "-C", ninja_out_path, "c_v8" });
    step.dependOn(&run_ninja.step);

    return step;
}

fn getArchOs(alloc: std.mem.Allocator, arch: std.Target.Cpu.Arch, os: std.Target.Os.Tag) []const u8 {
    return std.fmt.allocPrint(alloc, "{s}-{s}-gnu", .{ @tagName(arch), @tagName(os) }) catch unreachable;
}

fn getTargetId(alloc: std.mem.Allocator, target: std.Build.ResolvedTarget) []const u8 {
    return std.fmt.allocPrint(alloc, "{s}-{s}", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }) catch unreachable;
}

const CheckV8DepsStep = struct {
    const Self = @This();

    step: Step,
    b: *Builder,

    fn create(b: *Builder) *Self {
        const step = b.allocator.create(Self) catch unreachable;
        step.* = .{
            .step = Step.init(.custom, "check_v8_deps", b.allocator, make),
            .b = b,
        };
        return step;
    }

    fn make(step: *Step) !void {
        const self: *Self = @fieldParentPtr("step", step);

        const output = try self.b.execFromStep(&.{ "clang", "--version" }, step);
        print("clang: {s}", .{output});

        // TODO: Find out the actual minimum and check against other clang flavors.
        if (std.mem.startsWith(u8, output, "Homebrew clang version ")) {
            const i = std.mem.indexOfScalar(u8, output, '.').?;
            const major_v = try std.fmt.parseInt(u8, output["Homebrew clang version ".len..i], 10);
            if (major_v < 13) {
                return error.BadClangVersion;
            }
        }
    }
};

fn createGetV8(b: *Builder) *std.Build.Step {
    const step = b.step("get-v8", "Gets v8 source using gclient.");

    if (UseGclient) {
        const mkpath = MakePathStep.create(b, "./gclient");
        step.dependOn(&mkpath.step);

        // About depot_tools: https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up
        const cmd = b.addSystemCommand(&.{ b.pathFromRoot("./tools/depot_tools/fetch"), "v8" });
        cmd.cwd = "./gclient";
        cmd.addPathDir(b.pathFromRoot("./tools/depot_tools"));
        step.dependOn(&cmd.step);
    } else {
        const get = GetV8SourceStep.create(b);
        step.dependOn(&get.step);
    }
    return step;
}

fn createGetTools(b: *Builder) *std.Build.Step {
    const step = b.step("get-tools", "Gets the build tools.");

    //var sub_step = b.addSystemCommand(&.{ "python", "./tools/get_ninja_gn_binaries.py", "--dir", "./tools" });
    var sub_step = b.addSystemCommand(&.{ "git", "clone", "https://github.com/denoland/ninja_gn_binaries.git", "./tools" });
    step.dependOn(&sub_step.step);

    if (UseGclient) {
        // Pull depot_tools for fetch tool.
        sub_step = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://chromium.googlesource.com/chromium/tools/depot_tools.git", "tools/depot_tools" });
        step.dependOn(&sub_step.step);
    }

    return step;
}

fn getNinjaPath(b: *Builder) []const u8 {
    const platform = switch (builtin.os.tag) {
        .windows => "win",
        .linux => "linux",
        .macos => "mac",
        else => unreachable,
    };
    const arch = switch (builtin.cpu.arch) {
        .x86_64 => "amd64",
        .aarch64 => "arm64",
        else => unreachable,
    };
    const ext = if (builtin.os.tag == .windows) ".exe" else "";
    const bin = std.mem.concat(b.allocator, u8, &.{ "ninja", ext }) catch unreachable;
    const subFolder = std.mem.concat(b.allocator, u8, &.{ platform, "-", arch }) catch unreachable;
    return std.fs.path.resolve(b.allocator, &.{ "./tools", subFolder, bin }) catch unreachable;
}

fn getGnPath(b: *Builder) []const u8 {
    const platform = switch (builtin.os.tag) {
        .windows => "win",
        .linux => "linux",
        .macos => "mac",
        else => unreachable,
    };
    const arch = switch (builtin.cpu.arch) {
        .x86_64 => "amd64",
        .aarch64 => "arm64",
        else => unreachable,
    };
    const ext = if (builtin.os.tag == .windows) ".exe" else "";
    const bin = std.mem.concat(b.allocator, u8, &.{ "gn", ext }) catch unreachable;
    const subFolder = std.mem.concat(b.allocator, u8, &.{ platform, "-", arch }) catch unreachable;
    return std.fs.path.resolve(b.allocator, &.{ "./tools", subFolder, bin }) catch unreachable;
}

const MakePathStep = struct {
    const Self = @This();

    step: std.Build.Step,
    b: *Builder,
    path: []const u8,

    fn create(b: *Builder, root_path: []const u8) *Self {
        const new = b.allocator.create(Self) catch unreachable;
        new.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("make-path", .{}),
                .owner = b,
                .makeFn = make,
            }),
            .b = b,
            .path = root_path,
        };
        return new;
    }
    fn make(step: *std.Build.Step, prog_node: std.Progress.Node) anyerror!void {
        _ = prog_node;
        const self: *Self = @fieldParentPtr("step", step);
        const cwd = fs.cwd();

        const stat = try statPathFromRoot(self.b, self.path);
        if (stat == .NotExist) {
            try cwd.makeDir(self.path);
        }
    }
};

const CopyFileStep = struct {
    const Self = @This();

    step: std.Build.Step,
    b: *Builder,
    src_path: []const u8,
    dst_path: []const u8,

    fn create(b: *Builder, src_path: []const u8, dst_path: []const u8) *Self {
        const new = b.allocator.create(Self) catch unreachable;
        new.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = b.fmt("cp", .{}),
                .owner = b,
                .makeFn = make,
            }),
            .b = b,
            .src_path = src_path,
            .dst_path = dst_path,
        };
        return new;
    }

    fn make(step: *std.Build.Step, prog_node: std.Progress.Node) anyerror!void {
        _ = prog_node;
        const self: *Self = @fieldParentPtr("step", step);
        try std.fs.copyFileAbsolute(self.src_path, self.dst_path, .{});
    }
};

// TODO: Make this usable from external project.
fn linkV8(b: *Builder, step: *std.Build.Step.Compile, mode: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget, use_zig_tc: bool) void {
    const mode_str: []const u8 = if (mode == .Debug) "debug" else "release";
    const lib: []const u8 = if (target.result.os.tag == .windows and target.result.abi == .msvc) "c_v8.lib" else "libc_v8.a";
    const lib_path = std.fmt.allocPrint(b.allocator, "./v8-build/{s}/{s}/ninja/obj/zig/{s}", .{
        getTargetId(b.allocator, target),
        mode_str,
        lib,
    }) catch unreachable;
    step.addAssemblyFile(b.path(lib_path));
    if (builtin.os.tag == .linux) {
        if (use_zig_tc) {
            // TODO: This should be linked already when we built v8.
            step.linkLibCpp();
        }
        step.linkSystemLibrary("unwind");
    } else if (target.result.os.tag == .windows) {
        if (target.result.abi == .gnu) {
            step.linkLibCpp();
        } else {
            step.linkSystemLibrary("Dbghelp");
            step.linkSystemLibrary("Winmm");
            step.linkSystemLibrary("Advapi32");

            // We need libcpmt to statically link with c++ stl for exception_ptr references from V8.
            // Zig already adds the SDK path to the linker but doesn't sync it to the internal libs array which linkSystemLibrary checks against.
            // For now we'll hardcode the MSVC path here.
            step.addLibraryPath(b.path("C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/lib/x64"));
            step.linkSystemLibrary("libcpmt");
        }
    }
}

fn createTest(b: *Builder, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode, use_zig_tc: bool) *std.Build.Step.Compile {
    const step = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = mode,
    }); //FIXED

    step.addIncludePath(b.path("src"));
    step.linkLibC();

    linkV8(b, step, mode, target, use_zig_tc);

    return step;
}

const DepEntry = struct {
    const Self = @This();

    alloc: std.mem.Allocator,
    repo_url: []const u8,
    repo_rev: []const u8,

    pub fn deinit(self: Self) void {
        self.alloc.free(self.repo_url);
        self.alloc.free(self.repo_rev);
    }
};

fn getV8Rev(b: *Builder) ![]const u8 {
    var file: std.fs.File = undefined;
    if (comptime isMinZigVersion()) {
        file = try std.fs.openFileAbsolute(b.pathFromRoot("V8_REVISION"), .{ .read = true, .write = false });
    } else {
        file = try std.fs.openFileAbsolute(b.pathFromRoot("V8_REVISION"), .{ .mode = std.fs.File.OpenMode.read_write });
    }
    defer file.close();
    return std.mem.trim(u8, try file.readToEndAlloc(b.allocator, 1e9), "\n\r ");
}

pub const GetV8SourceStep = struct {
    const Self = @This();

    step: Step,
    b: *Builder,

    pub fn create(b: *Builder) *Self {
        const self = b.allocator.create(Self) catch unreachable;
        self.* = .{
            .b = b,
            .step = Step.init(.{
                .id = .run,
                .name = "Get V8 Sources.",
                .owner = b,
                .makeFn = make,
            }),
        };
        return self;
    }

    fn parseDep(self: Self, deps: json.Value, key: []const u8) !DepEntry {
        const val = deps.object.get(key).?;

        const i = std.mem.lastIndexOfScalar(u8, val.string, '@').?;
        const repo_rev = try self.b.allocator.dupe(u8, val.string[i + 1 ..]);

        const repo_url = try std.mem.replaceOwned(u8, self.b.allocator, val.string[0..i], "@chromium_url", "https://chromium.googlesource.com");
        return DepEntry{
            .alloc = self.b.allocator,
            .repo_url = repo_url,
            .repo_rev = repo_rev,
        };
    }

    fn getDep(self: *Self, deps: json.Value, key: []const u8, local_path: []const u8) !void {
        const dep = try self.parseDep(deps, key);
        defer dep.deinit();

        const stat = try statPathFromRoot(self.b, local_path);
        if (stat == .NotExist) {
            _ = self.b.run(&.{ "git", "clone", dep.repo_url, local_path });
        }
        _ = self.b.run(&.{ "git", "-C", local_path, "checkout", dep.repo_rev });
        if (stat == .NotExist) {
            // Apply patch for v8/build
            if (std.mem.eql(u8, key, "build")) {
                _ = self.b.run(&.{ "git", "apply", "--ignore-space-change", "--ignore-whitespace", "patches/v8_build.patch", "--directory=v8/build" });
            }
        }
    }

    fn runHook(self: *Self, hooks: json.Value, name: []const u8) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();

        defer _ = gpa.deinit();

        for (hooks.array.items) |hook| {
            if (std.mem.eql(u8, name, hook.object.get("name").?.string)) {
                const cmd = hook.object.get("action").?.array;
                var args = std.ArrayList([]const u8).init(self.b.allocator);
                defer args.deinit();
                for (cmd.items) |it| {
                    try args.append(it.string);
                }
                const cwd = self.b.pathFromRoot("v8");

                const cmd_path = try std.fmt.allocPrint(alloc, "{s}/{s}", .{ cwd, args.items[1] });
                defer alloc.free(cmd_path);

                _ = self.b.run(&.{ args.items[0], cmd_path });
                break;
            }
        }
    }

    fn make(step: *Step, prog_node: std.Progress.Node) !void {
        _ = prog_node;
        const self: *Self = @fieldParentPtr("step", step);

        // Pull the minimum source we need by looking at DEPS.
        // TODO: Check if we have the right branches, otherwise reclone.

        // Get revision/tag to checkout.
        const v8_rev = try getV8Rev(self.b);

        // Clone V8.
        const stat = try statPathFromRoot(self.b, "v8");
        if (stat == .NotExist) {
            _ = self.b.run(&.{ "git", "clone", "--depth=1", "--branch", v8_rev, "https://chromium.googlesource.com/v8/v8.git", "v8" });
            // Apply patch for v8 root.
            _ = self.b.run(&.{ "git", "apply", "--ignore-space-change", "--ignore-whitespace", "patches/v8.patch", "--directory=v8" });
        }

        // Get DEPS in json.
        const deps_json = self.b.run(&.{ "python3", "parse_deps.py", "v8/DEPS" });
        defer self.b.allocator.free(deps_json);

        var tree = try json.parseFromSlice(json.Value, self.b.allocator, deps_json, .{});
        defer tree.deinit();

        const deps = tree.value.object.get("deps").?;
        const hooks = tree.value.object.get("hooks").?;

        // build
        try self.getDep(deps, "build", "v8/build");

        // Add an empty gclient_args.gni so gn is happy. gclient also creates an empty file.
        const file = try std.fs.createFileAbsolute(self.b.pathFromRoot("v8/build/config/gclient_args.gni"), .{ .read = false, .truncate = true });
        try file.writeAll("# Generated from build.zig");

        file.close();

        // buildtools
        try self.getDep(deps, "buildtools", "v8/buildtools");

        // libc++
        try self.getDep(deps, "buildtools/third_party/libc++/trunk", "v8/buildtools/third_party/libc++/trunk");

        // tools/clang
        try self.getDep(deps, "tools/clang", "v8/tools/clang");

        try self.runHook(hooks, "clang");

        // third_party/zlib
        try self.getDep(deps, "third_party/zlib", "v8/third_party/zlib");

        // libc++abi
        try self.getDep(deps, "buildtools/third_party/libc++abi/trunk", "v8/buildtools/third_party/libc++abi/trunk");

        // googletest
        try self.getDep(deps, "third_party/googletest/src", "v8/third_party/googletest/src");

        // trace_event
        try self.getDep(deps, "base/trace_event/common", "v8/base/trace_event/common");

        // jinja2
        try self.getDep(deps, "third_party/jinja2", "v8/third_party/jinja2");

        // markupsafe
        try self.getDep(deps, "third_party/markupsafe", "v8/third_party/markupsafe");

        // For windows.
        if (builtin.os.tag == .windows) {
            // lastchange.py is flaky when it tries to do git commands from subprocess.Popen. Will sometimes get [WinError 50].
            // For now we'll just do it in zig.
            // try self.runHook(hooks, "lastchange");

            const merge_base_sha = "HEAD";
            const commit_filter = "^Change-Id:";
            const grep_arg = try std.fmt.allocPrint(self.b.allocator, "--grep={s}", .{commit_filter});
            const version_info = try self.b.execFromStep(&.{ "git", "-C", "v8/build", "log", "-1", "--format=%H %ct", grep_arg, merge_base_sha }, &self.step);
            const idx = std.mem.indexOfScalar(u8, version_info, ' ').?;
            const commit_timestamp = version_info[idx + 1 ..];

            // build/timestamp.gni expects the file to be just the unix timestamp.
            const write = std.fs.createFileAbsolute(self.b.pathFromRoot("v8/build/util/LASTCHANGE.committime"), .{ .truncate = true }) catch unreachable;
            defer write.close();
            write.writeAll(commit_timestamp) catch unreachable;
        }
    }
};

fn createBuildExeStep(b: *Builder, path: []const u8, target: std.Build.ResolvedTarget, mode: std.builtin.OptimizeMode, use_zig_tc: bool) *std.Build.Step.Compile {
    _ = b.step("exe", "Build exe with main file at -Dpath");

    const basename = std.fs.path.basename(path);
    const i = std.mem.indexOf(u8, basename, ".zig") orelse basename.len;
    const name = basename[0..i];

    const step = b.addExecutable(.{
        .target = target,
        .root_source_file = b.path(path),
        .name = name,
        .optimize = mode,
    }); //FIXED
    //step.setBuildMode(mode);
    //step.setTarget(target);

    step.linkLibC();
    step.addIncludePath(b.path("src"));

    if (mode == .ReleaseSafe) {
        step.root_module.strip = true;
    }

    linkV8(b, step, mode, target, use_zig_tc);

    return step;
}

const PathStat = enum {
    NotExist,
    Directory,
    File,
    SymLink,
    Unknown,
};

fn statPathFromRoot(b: *Builder, path_rel: []const u8) !PathStat {
    const path_abs = b.pathFromRoot(path_rel);
    var file: std.fs.File = undefined;
    if (comptime isMinZigVersion()) {
        file = std.fs.openFileAbsolute(path_abs, .{ .read = false, .write = false }) catch |err| {
            if (err == error.FileNotFound) {
                return .NotExist;
            } else if (err == error.IsDir) {
                return .Directory;
            } else {
                return err;
            }
        };
    } else {
        file = std.fs.openFileAbsolute(path_abs, .{ .mode = std.fs.File.OpenMode.read_only }) catch |err| {
            if (err == error.FileNotFound) {
                return .NotExist;
            } else if (err == error.IsDir) {
                return .Directory;
            } else {
                return err;
            }
        };
    }
    defer file.close();

    const stat = try file.stat();
    switch (stat.kind) {
        .sym_link => return .SymLink,
        .directory => return .Directory,
        .file => return .File,
        else => return .Unknown,
    }
}

fn isMinZigVersion() bool {
    return builtin.zig_version.major == 0 and builtin.zig_version.minor == 9;
}
