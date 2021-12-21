const std = @import("std");
const json = std.json;
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const print = std.debug.print;
const builtin = @import("builtin");
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) !void {
    // Options.
    //const build_v8 = b.option(bool, "build_v8", "Whether to build from v8 source") orelse false;
    const path = b.option([]const u8, "path", "Path to main file, for: build, run") orelse "";

    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const get_tools = createGetTools(b);
    b.step("get-tools", "Gets the build tools.").dependOn(&get_tools.step);

    const get_v8 = createGetV8(b);
    b.step("get-v8", "Gets v8 source using gclient.").dependOn(get_v8);

    const v8 = try createV8_Build(b, target, mode);
    b.step("v8", "Build v8 c binding lib.").dependOn(&v8.step);

    const run_test = createTest(b, target, mode);
    b.step("test", "Run tests.").dependOn(&run_test.step);

    const build_exe = createBuildExeStep(b, path, target, mode);
    b.step("exe", "Build exe with main file at -Dpath").dependOn(&build_exe.step);

    const run_exe = build_exe.run();
    b.step("run", "Run with main file at -Dpath").dependOn(&run_exe.step);

    b.default_step.dependOn(&v8.step);
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
fn createV8_Build(b: *Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) !*std.build.LogStep {
    const step = b.addLog("Built V8\n", .{});

    if (UseGclient) {
        const mkpath = MakePathStep.create(b, "./gclient/v8/zig");
        step.step.dependOn(&mkpath.step);

        const cp = CopyFileStep.create(b, b.pathFromRoot("BUILD.gclient.gn"), b.pathFromRoot("gclient/v8/zig/BUILD.gn"));
        step.step.dependOn(&cp.step);
    } else {
        const mkpath = MakePathStep.create(b, "./v8/zig");
        step.step.dependOn(&mkpath.step);

        const cp = CopyFileStep.create(b, b.pathFromRoot("BUILD.gn"), b.pathFromRoot("v8/zig/BUILD.gn"));
        step.step.dependOn(&cp.step);
    }

    var gn_args = std.ArrayList([]const u8).init(b.allocator);

    switch (target.getOsTag()) {
        .macos => try gn_args.append("target_os=\"mac\""),
        .windows => {
            try gn_args.append("target_os=\"win\"");
            if (!UseGclient) {
                // Don't use depot_tools.
                try b.env_map.put("DEPOT_TOOLS_WIN_TOOLCHAIN", "0");
            }
        },
        .linux => try gn_args.append("target_os=\"linux\""),
        else => {},
    }
    if (target.getCpuArch() == .x86_64) {
        try gn_args.append("target_cpu=\"x64\"");
    }

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

    // sccache
    if (b.env_map.get("SCCACHE")) |path| {
        const cc_wrapper = try std.fmt.allocPrint(b.allocator, "cc_wrapper=\"{s}\"", .{path});
        try gn_args.append(cc_wrapper);
    } else {
        if (builtin.os.tag == .windows) {
            // findProgram look for "PATH" case sensitive.
            try b.env_map.put("PATH", b.env_map.get("Path") orelse "");
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
            b.env_map.remove("PATH");
        }
    }

    // var check_deps = CheckV8DepsStep.create(b);
    // step.step.dependOn(&check_deps.step);

    const mode_str: []const u8 = if (mode == .Debug) "debug" else "release";
    // GN will generate ninja build files in ninja_out_path which will also contain the artifacts after running ninja.
    const ninja_out_path = try std.fmt.allocPrint(b.allocator, "v8-out/{s}/{s}/ninja", .{
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
    // cd gclient/v8 && gn desc ../../v8-out/x86_64-linux/release/ninja/ :v8 --tree
    // We can't see our own config because gn desc doesn't accept a --root-target.
    // One idea is to append our BUILD.gn to the v8 BUILD.gn instead of putting it in a subdirectory.
    if (UseGclient) {
        var run_gn = b.addSystemCommand(&.{ gn, "--root=gclient/v8", "--root-target=//zig", "--dotfile=.gn", "gen", ninja_out_path, args });
        step.step.dependOn(&run_gn.step);
    } else {
        var run_gn = b.addSystemCommand(&.{ gn, "--root=v8", "--root-target=//zig", "--dotfile=.gn", "gen", ninja_out_path, args });
        step.step.dependOn(&run_gn.step);
    }

    const ninja = getNinjaPath(b);
    // Only build our target. If no target is specified, ninja will build all the targets which includes developer tools, tests, etc.
    var run_ninja = b.addSystemCommand(&.{ ninja, "-C", ninja_out_path, "c_v8" });
    step.step.dependOn(&run_ninja.step);

    return step;
}

fn getTargetId(alloc: std.mem.Allocator, target: std.zig.CrossTarget) []const u8 {
    return std.fmt.allocPrint(alloc, "{s}-{s}", .{ @tagName(target.getCpuArch()), @tagName(target.getOsTag()) }) catch unreachable;
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
        const self = @fieldParentPtr(Self, "step", step);

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

fn createGetV8(b: *Builder) *std.build.Step {
    if (UseGclient) {
        const mkpath = MakePathStep.create(b, "./gclient");

        // About depot_tools: https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up
        const cmd = b.addSystemCommand(&.{ b.pathFromRoot("./tools/depot_tools/fetch"), "v8" });
        cmd.cwd = "./gclient";
        cmd.addPathDir(b.pathFromRoot("./tools/depot_tools"));
        cmd.step.dependOn(&mkpath.step);
        return &cmd.step;
    } else {
        const step = GetV8SourceStep.create(b);
        return &step.step;
    }
}

fn createGetTools(b: *Builder) *std.build.LogStep {
    const step = b.addLog("Get Tools\n", .{});

    var sub_step = b.addSystemCommand(&.{ "python", "./tools/get_ninja_gn_binaries.py", "--dir", "./tools" });
    step.step.dependOn(&sub_step.step);

    if (UseGclient) {
        // Pull depot_tools for fetch tool.
        sub_step = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://chromium.googlesource.com/chromium/tools/depot_tools.git", "tools/depot_tools"});
        step.step.dependOn(&sub_step.step);
    }

    return step;
}

fn getNinjaPath(b: *Builder) []const u8 {
    const platform = switch (builtin.os.tag) {
        .windows => "win",
        .linux => "linux64",
        .macos => "mac",
        else => unreachable,
    };
    const ext = if (builtin.os.tag == .windows) ".exe" else "";
    const bin = std.mem.concat(b.allocator, u8, &.{ "ninja", ext }) catch unreachable;
    return std.fs.path.resolve(b.allocator, &.{ "./tools/ninja_gn_binaries-20210101", platform, bin }) catch unreachable;
}

fn getGnPath(b: *Builder) []const u8 {
    const platform = switch (builtin.os.tag) {
        .windows => "win",
        .linux => "linux64",
        .macos => "mac",
        else => unreachable,
    };
    const ext = if (builtin.os.tag == .windows) ".exe" else "";
    const bin = std.mem.concat(b.allocator, u8, &.{ "gn", ext }) catch unreachable;
    return std.fs.path.resolve(b.allocator, &.{ "./tools/ninja_gn_binaries-20210101", platform, bin }) catch unreachable;
}

const MakePathStep = struct {
    const Self = @This();

    step: std.build.Step,
    b: *Builder,
    path: []const u8,

    fn create(b: *Builder, root_path: []const u8) *Self {
        const new = b.allocator.create(Self) catch unreachable;
        new.* = .{
            .step = std.build.Step.init(.custom, b.fmt("make-path", .{}), b.allocator, make),
            .b = b,
            .path = root_path,
        };
        return new;
    }

    fn make(step: *std.build.Step) anyerror!void {
        const self = @fieldParentPtr(Self, "step", step);
        try self.b.makePath(self.path);
    }
};

const CopyFileStep = struct {
    const Self = @This();

    step: std.build.Step,
    b: *Builder,
    src_path: []const u8,
    dst_path: []const u8,

    fn create(b: *Builder, src_path: []const u8, dst_path: []const u8) *Self {
        const new = b.allocator.create(Self) catch unreachable;
        new.* = .{
            .step = std.build.Step.init(.custom, b.fmt("cp", .{}), b.allocator, make),
            .b = b,
            .src_path = src_path,
            .dst_path = dst_path,
        };
        return new;
    }

    fn make(step: *std.build.Step) anyerror!void {
        const self = @fieldParentPtr(Self, "step", step);
        try std.fs.copyFileAbsolute(self.src_path, self.dst_path, .{});
    }
};

fn linkV8(b: *Builder, step: *std.build.LibExeObjStep) void {
    const mode = step.build_mode;
    const target = step.target;

    const mode_str: []const u8 = if (mode == .Debug) "debug" else "release";
    const lib: []const u8 = if (builtin.os.tag == .windows) "c_v8.lib" else "libc_v8.a";
    const lib_path = std.fmt.allocPrint(b.allocator, "./v8-out/{s}/{s}/ninja/obj/zig/{s}", .{
        getTargetId(b.allocator, target),
        mode_str,
        lib,
    }) catch unreachable;
    step.addAssemblyFile(lib_path);
    if (builtin.os.tag == .linux) {
        step.linkSystemLibrary("unwind");
    } else if (builtin.os.tag == .windows) {
        step.linkSystemLibrary("Dbghelp");
        step.linkSystemLibrary("Winmm");
        step.linkSystemLibrary("Advapi32");

        // We need libcpmt to statically link with c++ stl for exception_ptr references from V8. 
        // Zig already adds the SDK path to the linker but doesn't sync it to the internal libs array which linkSystemLibrary checks against.
        // For now we'll hardcode the MSVC path here.
        step.addLibPath("C:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Tools/MSVC/14.29.30133/lib/x64");
        step.linkSystemLibrary("libcpmt");
    }
}

fn createTest(b: *Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) *std.build.LibExeObjStep {
    const step = b.addTest("./test/test.zig");
    step.setMainPkgPath(".");
    step.addIncludeDir("./src");
    step.setTarget(target);
    step.setBuildMode(mode);
    step.linkLibC();
    linkV8(b, step);
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
    const file = try std.fs.openFileAbsolute(b.pathFromRoot("V8_REVISION"), .{ .read = true, .write = false});
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
            .step = Step.init(.run, "Get V8 Sources.", b.allocator, make),
        };
        return self;
    }

    fn parseDep(self: Self, deps: json.Value, key: []const u8) !DepEntry {
        const val = deps.Object.get(key).?;

        const i = std.mem.lastIndexOfScalar(u8, val.String, '@').?;
        const repo_rev = try self.b.allocator.dupe(u8, val.String[i+1..]);

        const repo_url = try std.mem.replaceOwned(u8, self.b.allocator, val.String[0..i], "@chromium_url", "https://chromium.googlesource.com");
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
            _ = try self.b.execFromStep(&.{ "git", "clone", dep.repo_url, local_path }, &self.step);
        }
        _ = try self.b.execFromStep(&.{ "git", "-C", local_path, "checkout", dep.repo_rev }, &self.step);
    }

    fn runHook(self: *Self, hooks: json.Value, name: []const u8) !void {
        for (hooks.Array.items) |hook| {
            if (std.mem.eql(u8, name, hook.Object.get("name").?.String)) {
                const cmd = hook.Object.get("action").?.Array;
                var args = std.ArrayList([]const u8).init(self.b.allocator);
                defer args.deinit();
                for (cmd.items) |it| {
                    try args.append(it.String);
                }
                const cwd = self.b.pathFromRoot("v8");
                _ = try self.b.spawnChildEnvMap(cwd, self.b.env_map, args.items);
                break;
            }
        }
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);

        // Pull the minimum source we need by looking at DEPS.
        // TODO: Make this sync if we already pulled the sources.

        // Get revision/tag to checkout.
        const v8_rev = try getV8Rev(self.b);

        // Clone V8.
        // TODO: Check if we have the right branch, otherwise re clone v8.
        const stat = try statPathFromRoot(self.b, "v8");
        if (stat == .NotExist) {
            _ = try self.b.execFromStep(&.{ "git", "clone", "--depth=1", "--branch", v8_rev, "https://chromium.googlesource.com/v8/v8.git", "v8" }, &self.step);
        }

        // Get DEPS in json.
        const deps_json = try self.b.execFromStep(&.{ "python", "tools/parse_deps.py", "v8/DEPS" }, &self.step);
        defer self.b.allocator.free(deps_json);

        var p = json.Parser.init(self.b.allocator, false);
        defer p.deinit();

        var tree = try p.parse(deps_json);
        defer tree.deinit();

        var deps = tree.root.Object.get("deps").?;
        var hooks = tree.root.Object.get("hooks").?;

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
            const commit_timestamp = version_info[idx+1..];

            // build/timestamp.gni expects the file to be just the unix timestamp.
            const write = std.fs.createFileAbsolute(self.b.pathFromRoot("v8/build/util/LASTCHANGE.committime"), .{ .truncate = true }) catch unreachable;
            defer write.close();
            write.writeAll(commit_timestamp) catch unreachable; 
        }
    }
};

fn createBuildExeStep(b: *Builder, path: []const u8, target: std.zig.CrossTarget, mode: std.builtin.Mode) *LibExeObjStep {
    const basename = std.fs.path.basename(path);
    const i = std.mem.indexOf(u8, basename, ".zig") orelse basename.len;
    const name = basename[0..i];

    const step = b.addExecutable(name, path);
    step.setBuildMode(mode);
    step.setTarget(target);

    step.linkLibC();
    step.addIncludeDir("src");

    const output_dir_rel = std.fmt.allocPrint(b.allocator, "zig-out/{s}", .{ name }) catch unreachable;
    const output_dir = b.pathFromRoot(output_dir_rel);
    step.setOutputDir(output_dir);

    if (mode == .ReleaseSafe) {
        step.strip = true;
    }

    linkV8(b, step);

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
    const file = std.fs.openFileAbsolute(path_abs, .{ .read = false, .write = false }) catch |err| {
        if (err == error.FileNotFound) {
            return .NotExist;
        } else if (err == error.IsDir) {
            return .Directory;
        } else {
            return err;
        }
    };
    defer file.close();

    const stat = try file.stat();
    switch (stat.kind) {
        .SymLink => return .SymLink,
        .Directory => return .Directory,
        .File => return .File,
        else => return .Unknown,
    }
}
