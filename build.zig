const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const Step = std.build.Step;
const print = std.debug.print;
const builtin = @import("builtin");
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) !void {
    // Options.
    //const build_v8 = b.option(bool, "build_v8", "Whether to build from v8 source") orelse false;

    const get_tools = createGetTools(b);
    b.step("get-tools", "Gets the build tools.").dependOn(&get_tools.step);

    const get_v8 = createGetV8(b);
    b.step("get-v8", "Gets v8 source using gclient.").dependOn(&get_v8.step);

    const v8 = try createV8_Build(b);
    b.step("v8", "Build v8 c binding lib.").dependOn(&v8.step);

    const run_test = createTest(b);
    b.step("test", "Run tests.").dependOn(&run_test.step);

    b.default_step.dependOn(&v8.step);
}

// V8's build process is complex and porting it to zig could take quite awhile.
// It would be nice if there was a way to import .gn files into the zig build system.
// For now we just use gn/ninja like rusty_v8 does: https://github.com/denoland/rusty_v8/blob/main/build.rs
fn createV8_Build(b: *Builder) !*std.build.LogStep {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const step = b.addLog("Built V8\n", .{});

    const mkpath = MakePathStep.create(b, "./gclient/v8/zig");
    step.step.dependOn(&mkpath.step);

    const cp = CopyFileStep.create(b, b.pathFromRoot("BUILD.gn"), b.pathFromRoot("gclient/v8/zig/BUILD.gn"));
    step.step.dependOn(&cp.step);

    var gn_args = std.ArrayList([]const u8).init(b.allocator);
    if (mode == .Debug) {
        try gn_args.append("is_debug=true");
    } else {
        try gn_args.append("is_debug=false");
        // No symbols. This will eventually pass down to v8_symbol_level.
        try gn_args.append("symbol_level=0");
    }

    if (mode != .Debug) {
        // TODO: document
        try gn_args.append("v8_enable_handle_zapping=false");
    }

    // Fix GN's host_cpu detection when using x86_64 bins on Apple Silicon
    if (builtin.os.tag == .macos and builtin.os.arch == .aarch64) {
        try gn_args.append("host_cpu=\"arm64\"");
    }

    // sccache
    if (b.env_map.get("SCCACHE")) |path| {
        const cc_wrapper = try std.fmt.allocPrint(b.allocator, "cc_wrapper=\"{s}\"", .{path});
        try gn_args.append(cc_wrapper);
    } else {
        if (b.findProgram(&.{"sccache"}, &.{})) |_| {
            const cc_wrapper = try std.fmt.allocPrint(b.allocator, "cc_wrapper=\"{s}\"", .{"sccache"});
            try gn_args.append(cc_wrapper);
        } else |err| {
            if (err != error.FileNotFound) {
                unreachable;
            }
        }
    }

    // var check_deps = CheckV8DepsStep.create(b);
    // step.step.dependOn(&check_deps.step);

    const mode_str: []const u8 = if (mode == .Debug) "debug" else "release";
    // GN will generate ninja build files in ninja_out_path which will also contain the artifacts after running ninja.
    const ninja_out_path = try std.fmt.allocPrint(b.allocator, "v8-out/{s}-{s}/{s}/ninja", .{
        @tagName(target.getCpuArch()),
        @tagName(target.getOsTag()),
        mode_str,
    });

    const gn = getGnPath(b);
    const arg_items = try std.mem.join(b.allocator, " ", gn_args.items);
    const args = try std.mem.join(b.allocator, "", &.{ "--args=", arg_items });
    // Currently we have to use gclient/v8 as the source root since all those nested gn files expects it, (otherwise, we'll run into duplicate argument declaration errors.)
    // --dotfile lets us use a different .gn outside of the source root.
    // --root-target is a directory that must be inside the source root where we can have a custom BUILD.gn.
    //      Since gclient/v8 is not part of our repo, we copy over BUILD.gn to gclient/v8/zig/BUILD.gn before we run gn.
    var run_gn = b.addSystemCommand(&.{ gn, "--root=gclient/v8", "--root-target=//zig", "--dotfile=.gn", "gen", ninja_out_path, args });
    step.step.dependOn(&run_gn.step);

    const ninja = getNinjaPath(b);
    var run_ninja = b.addSystemCommand(&.{ ninja, "-C", ninja_out_path });
    step.step.dependOn(&run_ninja.step);

    return step;
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

fn createGetV8(b: *Builder) *std.build.RunStep {
    const mkpath = MakePathStep.create(b, "./gclient");

    // About depot_tools: https://commondatastorage.googleapis.com/chrome-infra-docs/flat/depot_tools/docs/html/depot_tools_tutorial.html#_setting_up
    const cmd = b.addSystemCommand(&.{ b.pathFromRoot("./tools/depot_tools/fetch"), "v8" });
    cmd.cwd = "./gclient";
    cmd.addPathDir(b.pathFromRoot("./tools/depot_tools"));
    cmd.step.dependOn(&mkpath.step);

    return cmd;
}

fn createGetTools(b: *Builder) *std.build.RunStep {
    const step = b.addSystemCommand(&.{ "python", "./tools/get_ninja_gn_binaries.py", "--dir", "./tools" });
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
    return std.fs.path.resolve(b.allocator, &.{ "./tools/ninja_gn_binaries-20210101", platform, "ninja", ext }) catch unreachable;
}

fn getGnPath(b: *Builder) []const u8 {
    const platform = switch (builtin.os.tag) {
        .windows => "win",
        .linux => "linux64",
        .macos => "mac",
        else => unreachable,
    };
    const ext = if (builtin.os.tag == .windows) ".exe" else "";
    return std.fs.path.resolve(b.allocator, &.{ "./tools/ninja_gn_binaries-20210101", platform, "gn", ext }) catch unreachable;
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

fn createTest(b: *Builder) *std.build.LibExeObjStep {
    const step = b.addTest("./test/test.zig");
    step.setMainPkgPath(".");
    step.addIncludeDir("./src");
    step.linkLibC();
    step.addAssemblyFile("./v8-out/ninja/obj/zig/libc_v8.a");
    if (builtin.os.tag == .linux) {
        step.linkSystemLibrary("unwind");
    }
    return step;
}