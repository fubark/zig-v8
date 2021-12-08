const std = @import("std");
const t = std.testing;
const v8 = @import("../src/v8.zig");

test {
    // Based on https://chromium.googlesource.com/v8/v8/+/branch-heads/6.8/samples/hello-world.cc

    const platform = v8.createDefaultPlatform(0, true);
    defer v8.destroyPlatform(platform);
    v8.initPlatform(platform);

    v8.initV8();
    defer {
        _ = v8.deinitV8();
        v8.deinitV8Platform();
    }

    var params = v8.initCreateParams();
    params.array_buffer_allocator = v8.createDefaultArrayBufferAllocator();
    defer v8.destroyArrayBufferAllocator(params.array_buffer_allocator.?);

    const isolate = v8.createIsolate(&params);
    v8.enterIsolate(isolate);
    defer {
        v8.exitIsolate(isolate);
        v8.destroyIsolate(isolate);
    }

    // Create a stack-allocated handle scope.
    var handle_scope = v8.initHandleScope(isolate);
    defer v8.deinitHandleScope(&handle_scope);

    // Create a new context.
    var context = v8.createContext(isolate, null, null);
    v8.enterContext(context);
    defer v8.exitContext(context);

    // Create a string containing the JavaScript source code.
    const source = v8.createUtfString(isolate, "'Hello' + ', World! 🍏🍓' + Math.sin(Math.PI/2)");

    // Compile the source code.
    const script = v8.compileScript(context, source);

    // Run the script to get the result.
    const value = v8.runScript(context, script);

    // Convert the result to an UTF8 string and print it.
    const res = v8.valueToRawStringAlloc(t.allocator, isolate, context, value);
    defer t.allocator.free(res);

    std.log.info("{s}", .{res});
    try t.expectEqualStrings(res, "Hello, World! 🍏🍓1");
}