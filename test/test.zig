const std = @import("std");
const t = std.testing;
const v8 = @import("../src/v8.zig");

test {
    // Based on https://chromium.googlesource.com/v8/v8/+/branch-heads/6.8/samples/hello-world.cc

    const platform = v8.Platform.initDefault(0, true);
    defer platform.deinit();

    std.debug.print("v8 version: {s}\n", .{v8.getVersion()});

    v8.initV8Platform(platform);
    v8.initV8();
    defer {
        _ = v8.deinitV8();
        v8.deinitV8Platform();
    }

    var params = v8.initCreateParams();
    params.array_buffer_allocator = v8.createDefaultArrayBufferAllocator();
    defer v8.destroyArrayBufferAllocator(params.array_buffer_allocator.?);

    var isolate = v8.Isolate.init(&params);
    defer isolate.deinit();

    isolate.enter();
    defer isolate.exit();

    // Create a stack-allocated handle scope.
    var hscope: v8.HandleScope = undefined;
    hscope.init(isolate);
    defer hscope.deinit();

    // Create a new context.
    var context = v8.Context.init(isolate, null, null);
    context.enter();
    defer context.exit();

    // Create a string containing the JavaScript source code.
    const source = v8.createUtf8String(isolate, "'Hello' + ', World! 🍏🍓' + Math.sin(Math.PI/2)");

    // Compile the source code.
    const script = v8.compileScript(context, source, null).?;

    // Run the script to get the result.
    const value = v8.runScript(context, script).?;

    // Convert the result to an UTF8 string and print it.
    const res = valueToRawUtf8Alloc(t.allocator, isolate, context, value);
    defer t.allocator.free(res);

    std.log.info("{s}", .{res});
    try t.expectEqualStrings(res, "Hello, World! 🍏🍓1");
}

pub fn valueToRawUtf8Alloc(alloc: std.mem.Allocator, isolate: v8.Isolate, ctx: v8.Context, val: *const v8.Value) []const u8 {
    const str = v8.valueToString(ctx, val);
    const len = v8.utf8Len(isolate, str);
    const buf = alloc.alloc(u8, len) catch unreachable;
    _ = v8.writeUtf8String(str, isolate, buf);
    return buf;
}