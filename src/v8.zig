const std = @import("std");

const c = @cImport({
    @cInclude("binding.h");
});

/// Must be called first before initV8()
/// Returns a new instance of the default v8::Platform implementation.
///
/// |thread_pool_size| is the number of worker threads to allocate for
/// background jobs. If a value of zero is passed, a suitable default
/// based on the current number of processors online will be chosen.
/// If |idle_task_support| is enabled then the platform will accept idle
/// tasks (IdleTasksEnabled will return true) and will rely on the embedder
/// calling v8::platform::RunIdleTasks to process the idle tasks.
pub fn createDefaultPlatform(thread_pool_size: u32, idle_task_support: bool) *c.Platform {
    // Verify struct sizes.
    std.debug.assert(@sizeOf(c.CreateParams) == c.v8__Isolate__CreateParams__SIZEOF());
    return c.v8__Platform__NewDefaultPlatform(@intCast(c_int, thread_pool_size), if (idle_task_support) 1 else 0).?;
}

pub fn initPlatform(platform: *c.Platform) void {
    c.v8__V8__InitializePlatform(platform);
}

pub fn destroyPlatform(platform: *c.Platform) void {
    c.v8__Platform__DELETE(platform);
}

pub fn initV8() void {
    c.v8__V8__Initialize();
}

pub fn deinitV8() bool {
    return c.v8__V8__Dispose() == 1;
}

pub fn deinitV8Platform() void {
    c.v8__V8__ShutdownPlatform();
}

pub fn initCreateParams() c.CreateParams {
    var params: c.CreateParams = undefined;
    c.v8__Isolate__CreateParams__CONSTRUCT(&params);
    return params;
}

pub fn createDefaultArrayBufferAllocator() *c.ArrayBufferAllocator {
    return c.v8__ArrayBuffer__Allocator__NewDefaultAllocator().?;
}

pub fn destroyArrayBufferAllocator(alloc: *c.ArrayBufferAllocator) void {
    c.v8__ArrayBuffer__Allocator__DELETE(alloc);
}

pub fn createIsolate(params: *const c.CreateParams) *c.Isolate {
    const ptr = @intToPtr(*c.CreateParams, @ptrToInt(params));
    return c.v8__Isolate__New(ptr).?;
}

pub fn destroyIsolate(isolate: *c.Isolate) void {
    c.v8__Isolate__Dispose(isolate);
}

pub fn enterIsolate(isolate: *c.Isolate) void {
    c.v8__Isolate__Enter(isolate);
}

pub fn exitIsolate(isolate: *c.Isolate) void {
    c.v8__Isolate__Exit(isolate);
}

pub fn initHandleScope(isolate: *c.Isolate) c.HandleScope {
    var scope: c.HandleScope = undefined;
    c.v8__HandleScope__CONSTRUCT(&scope, isolate);
    return scope;
}

pub fn deinitHandleScope(scope: *c.HandleScope) void {
    c.v8__HandleScope__DESTRUCT(scope);
}

/// Creates a new context and returns a handle to the newly allocated
/// context.
///
/// \param isolate The isolate in which to create the context.
///
/// \param extensions An optional extension configuration containing
/// the extensions to be installed in the newly created context.
///
/// \param global_template An optional object template from which the
/// global object for the newly created context will be created.
///
/// \param global_object An optional global object to be reused for
/// the newly created context. This global object must have been
/// created by a previous call to Context::New with the same global
/// template. The state of the global object will be completely reset
/// and only object identify will remain.
pub fn createContext(isolate: *c.Isolate, global_tmpl: ?*c.ObjectTemplate, global_obj: ?*c.Value) *c.Context {
    return c.v8__Context__New(isolate, global_tmpl, global_obj).?;
}

pub fn enterContext(ctx: *c.Context) void {
    c.v8__Context__Enter(ctx);
}

pub fn exitContext(ctx: *c.Context) void {
    c.v8__Context__Exit(ctx);
}

pub fn createUtfString(isolate: *c.Isolate, str: []const u8) *const c.String {
    return c.v8__String__NewFromUtf8(isolate, str.ptr, c.kNormal, @intCast(c_int, str.len)).?;
}

pub fn compileScript(ctx: *const c.Context, src: *const c.String) *const c.Script {
    return c.v8__Script__Compile(ctx, src, null).?;
}

pub fn runScript(ctx: *const c.Context, script: *const c.Script) *const c.Value {
    return c.v8__Script__Run(script, ctx).?;
}

pub fn writeUtf8String(str: *const c.String, isolate: *c.Isolate, buf: []const u8) u32 {
    const options = c.NO_NULL_TERMINATION | c.REPLACE_INVALID_UTF8;
    // num chars is how many utf8 characters are actually written and the function returns how many bytes were written.
    var nchars: c_int = 0;
    // TODO: Return num chars
    return @intCast(u32, c.v8__String__WriteUtf8(str, isolate, buf.ptr, @intCast(c_int, buf.len), &nchars, options));
}

pub fn valueToRawStringAlloc(alloc: *std.mem.Allocator, isolate: *c.Isolate, ctx: *const c.Context, val: *const c.Value) []const u8 {
    const str = valueToString(ctx, val);
    const len = utf8Len(isolate, str);
    const buf = alloc.alloc(u8, len) catch unreachable;
    _ = writeUtf8String(str, isolate, buf);
    return buf;
}

pub fn valueToString(ctx: *const c.Context, val: *const c.Value) *const c.String {
    return c.v8__Value__ToString(val, ctx).?;
}

pub fn utf8Len(isolate: *c.Isolate, str: *const c.String) u32 {
    return @intCast(u8, c.v8__String__Utf8Length(str, isolate));
}