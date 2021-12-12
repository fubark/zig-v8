const std = @import("std");

const c = @cImport({
    @cInclude("binding.h");
});

pub const PropertyAttribute = struct {
    pub const None = c.None;
};

// Currently, user callback functions passed into FunctionTemplate will need to have this declared as a param and then
// converted to FunctionCallbackInfo to get a nicer interface.
pub const RawFunctionCallbackInfo = c.FunctionCallbackInfo;

pub const Platform = struct {
    const Self = @This();

    handle: *c.Platform,

    /// Must be called first before initV8Platform and initV8
    /// Returns a new instance of the default v8::Platform implementation.
    ///
    /// |thread_pool_size| is the number of worker threads to allocate for
    /// background jobs. If a value of zero is passed, a suitable default
    /// based on the current number of processors online will be chosen.
    /// If |idle_task_support| is enabled then the platform will accept idle
    /// tasks (IdleTasksEnabled will return true) and will rely on the embedder
    /// calling v8::platform::RunIdleTasks to process the idle tasks.
    pub fn initDefault(thread_pool_size: u32, idle_task_support: bool) Self {
        // Verify struct sizes.
        const assert = std.debug.assert;
        assert(@sizeOf(c.CreateParams) == c.v8__Isolate__CreateParams__SIZEOF());
        assert(@sizeOf(c.TryCatch) == c.v8__TryCatch__SIZEOF());
        return .{
            .handle = c.v8__Platform__NewDefaultPlatform(@intCast(c_int, thread_pool_size), if (idle_task_support) 1 else 0).?,
        };
    }

    pub fn deinit(self: Self) void {
        c.v8__Platform__DELETE(self.handle);
    }

    /// [V8]
    /// Pumps the message loop for the given isolate.
    ///
    /// The caller has to make sure that this is called from the right thread.
    /// Returns true if a task was executed, and false otherwise. If the call to
    /// PumpMessageLoop is nested within another call to PumpMessageLoop, only
    /// nestable tasks may run. Otherwise, any task may run. Unless requested through
    /// the |behavior| parameter, this call does not block if no task is pending. The
    /// |platform| has to be created using |NewDefaultPlatform|.
    pub fn pumpMessageLoop(self: Self, isolate: Isolate, wait_for_work: bool) bool {
        return c.v8__Platform__PumpMessageLoop(self.handle, isolate.handle, wait_for_work);
    }
};

pub fn getVersion() []const u8 {
    const str = c.v8__V8__GetVersion();
    const idx = std.mem.indexOfSentinel(u8, 0, str);
    return str[0..idx];
}

pub fn initV8Platform(platform: Platform) void {
    c.v8__V8__InitializePlatform(platform.handle);
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

pub const Isolate = struct {
    const Self = @This();

    handle: *c.Isolate,

    pub fn init(params: *const c.CreateParams) Self {
        const ptr = @intToPtr(*c.CreateParams, @ptrToInt(params));
        return .{
            .handle = c.v8__Isolate__New(ptr).?,
        };
    }

    /// [V8]
    /// Disposes the isolate.  The isolate must not be entered by any
    /// thread to be disposable.
    pub fn deinit(self: Self) void {
        c.v8__Isolate__Dispose(self.handle);
    }

    /// [V8]
    /// Sets this isolate as the entered one for the current thread.
    /// Saves the previously entered one (if any), so that it can be
    /// restored when exiting.  Re-entering an isolate is allowed.
    /// [Notes]
    /// This is equivalent to initing an Isolate Scope.
    pub fn enter(self: *Self) void {
        c.v8__Isolate__Enter(self.handle);
    }

    /// [V8]
    /// Exits this isolate by restoring the previously entered one in the
    /// current thread.  The isolate may still stay the same, if it was
    /// entered more than once.
    ///
    /// Requires: this == Isolate::GetCurrent().
    /// [Notes]
    /// This is equivalent to deiniting an Isolate Scope.
    pub fn exit(self: *Self) void {
        c.v8__Isolate__Exit(self.handle);
    }

    pub fn getCurrentContext(self: Self) Context {
        return .{
            .handle = c.v8__Isolate__GetCurrentContext(self.handle).?,
        };
    }

};

pub const HandleScope = struct {
    const Self = @This();

    inner: c.HandleScope,

    /// [Notes]
    /// This starts a new stack frame to record objects created.
    pub fn init(self: *Self, isolate: Isolate) void {
        c.v8__HandleScope__CONSTRUCT(&self.inner, isolate.handle);
    }

    /// [Notes]
    /// This pops the scope frame and allows V8 to mark/free objects created since initHandleScope.
    /// In C++ code, this would happen automatically when the HandleScope var leaves the current scope.
    pub fn deinit(self: *Self) void {
        c.v8__HandleScope__DESTRUCT(&self.inner);
    }
};

pub const Context = struct {
    const Self = @This();

    handle: *c.Context,

    /// [V8]
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
    pub fn init(isolate: Isolate, global_tmpl: ?ObjectTemplate, global_obj: ?*c.Value) Self {
        return .{
            .handle = c.v8__Context__New(
                isolate.handle,
                if (global_tmpl != null) global_tmpl.?.handle else null,
                global_obj
            ).?,
        };
    }

    /// [V8]
    /// Enter this context.  After entering a context, all code compiled
    /// and run is compiled and run in this context.  If another context
    /// is already entered, this old context is saved so it can be
    /// restored when the new context is exited.
    pub fn enter(self: *Self) void {
        c.v8__Context__Enter(self.handle);
    }

    /// [V8]
    /// Exit this context.  Exiting the current context restores the
    /// context that was in place when entering the current context.
    pub fn exit(self: *Self) void {
        c.v8__Context__Exit(self.handle);
    }

    /// [V8]
    /// Returns the isolate associated with a current context.
    pub fn getIsolate(self: *const Self) *Isolate {
        return c.v8__Context__GetIsolate(self);
    }
};

pub const FunctionCallbackInfo = struct {
    const Self = @This();

    handle: *const c.FunctionCallbackInfo,

    pub fn initFromV8(val: ?*const c.FunctionCallbackInfo) Self {
        return .{
            .handle = val.?,
        };
    }

    pub fn length(self: Self) u32 {
        return @intCast(u32, c.v8__FunctionCallbackInfo__Length(self.handle));
    }

    pub fn getIsolate(self: Self) Isolate {
        return .{
            .handle = c.v8__FunctionCallbackInfo__GetIsolate(self.handle).?,
        };
    }

    pub fn getArg(self: Self, i: u32) Value {
        return .{
            .handle = c.v8__FunctionCallbackInfo__INDEX(self.handle, @intCast(c_int, i)).?,
        };
    }

    pub fn getReturnValue(self: Self) ReturnValue {
        var res: c.ReturnValue = undefined;
        c.v8__FunctionCallbackInfo__GetReturnValue(self.handle, &res);
        return .{
            .inner = res,
        };
    }
};

pub const ReturnValue = struct {
    const Self = @This();

    inner: c.ReturnValue,

    pub fn set(self: Self, value: anytype) void {
        c.v8__ReturnValue__Set(self.inner, getValueHandle(value));
    }

    pub fn get(self: Self) Value {
        return .{
            .handle = c.v8__ReturnValue__Get(self.inner).?,
        };
    }
};

pub const FunctionTemplate = struct {
    const Self = @This();

    handle: *const c.FunctionTemplate,

    pub fn initDefault(isolate: Isolate, callback: c.FunctionCallback) Self {
        return .{
            .handle = c.v8__FunctionTemplate__New__DEFAULT(isolate.handle, callback).?,
        };
    }
};

pub const ObjectTemplate = struct {
    const Self = @This();

    handle: *c.ObjectTemplate,

    pub fn initDefault(isolate: Isolate) Self {
        return .{
            .handle = c.v8__ObjectTemplate__New__DEFAULT(isolate.handle).?,
        };
    }

    pub fn init(isolate: Isolate, constructor: *const c.FunctionTemplate) Self {
        return .{
            .handle = c.v8__ObjectTemplate__New(isolate.handle, constructor).?,
        };
    }

    pub fn set(self: Self, key: anytype, value: anytype, attr: c.PropertyAttribute) void {
        c.v8__Template__Set(getTemplateHandle(self), getNameHandle(key), getDataHandle(value), attr);
    }

    pub fn initInstance(self: Self, ctx: Context) Object {
        return .{
            .handle = c.v8__ObjectTemplate__NewInstance(self.handle, ctx.handle).?,
        };
    }
};

pub const Object = struct {
    const Self = @This();

    handle: *const c.Object,
};

pub inline fn getValue(val: anytype) Value {
    return .{
        .handle = getValueHandle(val),
    };
}

inline fn getValueHandle(val: anytype) *const c.Value {
    return @ptrCast(*const c.Value, comptime switch (@TypeOf(val)) {
        Object => val.handle,
        Value => val.handle,
        String => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Value", .{@typeName(@TypeOf(val))})),
    });
}

inline fn getNameHandle(val: anytype) *const c.Name {
    return @ptrCast(*const c.Name, comptime switch (@TypeOf(val)) {
        *const c.String => val,
        String => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Name", .{@typeName(@TypeOf(val))})),
    });
}

inline fn getTemplateHandle(val: anytype) *const c.Template {
    return @ptrCast(*const c.Template, comptime switch (@TypeOf(val)) {
        ObjectTemplate => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Template", .{@typeName(@TypeOf(val))})),
    });
}

inline fn getDataHandle(val: anytype) *const c.Data {
    return @ptrCast(*const c.Data, comptime switch (@TypeOf(val)) {
        FunctionTemplate => val.handle,
        ObjectTemplate => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Data", .{@typeName(@TypeOf(val))})),
    });
}

pub const Message = struct {
    const Self = @This();

    handle: *const c.Message,

    pub fn getSourceLine(self: Self, ctx: Context) ?String {
        if (c.v8__Message__GetSourceLine(self.handle, ctx.handle)) |string| {
            return String{
                .handle = string,
            };
        } else return null;
    }

    pub fn getScriptResourceName(self: Self) *const c.Value {
        return c.v8__Message__GetScriptResourceName(self.handle).?;
    }

    pub fn getLineNumber(self: Self, ctx: Context) ?u32 {
        const num = c.v8__Message__GetLineNumber(self.handle, ctx.handle);
        return if (num >= 0) @intCast(u32, num) else null;
    }

    pub fn getStartColumn(self: Self) u32 {
        return @intCast(u32, c.v8__Message__GetStartColumn(self.handle));
    }

    pub fn getEndColumn(self: Self) u32 {
        return @intCast(u32, c.v8__Message__GetEndColumn(self.handle));
    }
};

pub const TryCatch = struct {
    const Self = @This();

    inner: c.TryCatch,

    // TryCatch is wrapped in a v8::Local so have to initialize in place.
    pub fn init(self: *Self, isolate: Isolate) void {
        c.v8__TryCatch__CONSTRUCT(&self.inner, isolate.handle);
    }

    pub fn deinit(self: *Self) void {
        c.v8__TryCatch__DESTRUCT(&self.inner);
    }

    pub fn hasCaught(self: Self) bool {
        return c.v8__TryCatch__HasCaught(&self.inner);
    }

    pub fn getException(self: Self) Value {
        return .{
            .handle = c.v8__TryCatch__Exception(&self.inner).?,
        };
    }

    pub fn getStackTrace(self: Self, ctx: Context) ?Value {
        if (c.v8__TryCatch__StackTrace(&self.inner, ctx.handle)) |value| {
            return Value{
                .handle = value,
            };
        } else return null;
    }

    pub fn getMessage(self: Self) ?Message {
        if (c.v8__TryCatch__Message(&self.inner)) |message| {
            return Message{
                .handle = message,
            };
        } else {
            return null;
        }
    }
};

pub const ScriptOrigin = struct {
    const Self = @This();

    inner: c.ScriptOrigin,

    // ScriptOrigin is not wrapped in a v8::Local so we don't care if it points to another copy.
    pub fn initDefault(isolate: Isolate, resource_name: *const c.Value) Self {
        var inner: c.ScriptOrigin = undefined;
        c.v8__ScriptOrigin__CONSTRUCT(&inner, isolate.handle, resource_name);
        return .{
            .inner = inner,
        };
    }
};

pub const String = struct {
    const Self = @This();

    handle: *const c.String,

    pub fn initUtf8(isolate: Isolate, str: []const u8) Self {
        return .{
            .handle = c.v8__String__NewFromUtf8(isolate.handle, str.ptr, c.kNormal, @intCast(c_int, str.len)).?,
        };
    }

    pub fn lenUtf8(self: Self, isolate: Isolate) u32 {
        return @intCast(u8, c.v8__String__Utf8Length(self.handle, isolate.handle));
    }

    pub fn writeUtf8(self: String, isolate: Isolate, buf: []const u8) u32 {
        const options = c.NO_NULL_TERMINATION | c.REPLACE_INVALID_UTF8;
        // num chars is how many utf8 characters are actually written and the function returns how many bytes were written.
        var nchars: c_int = 0;
        // TODO: Return num chars
        return @intCast(u32, c.v8__String__WriteUtf8(self.handle, isolate.handle, buf.ptr, @intCast(c_int, buf.len), &nchars, options));
    }
};

pub const Script = struct {
    const Self = @This();

    handle: *const c.Script,

    /// Null indicates there was an compile error.
    pub fn compile(ctx: Context, src: String, origin: ?ScriptOrigin) ?Self {
        if (c.v8__Script__Compile(ctx.handle, src.handle, if (origin != null) &origin.?.inner else null)) |handle| {
            return Self{
                .handle = handle,
            };
        } else return null;
    }

    /// Null indicates a runtime error.
    pub fn run(self: Self, ctx: Context) ?Value {
        if (c.v8__Script__Run(self.handle, ctx.handle)) |value| {
            return Value{
                .handle = value,
            };
        } else return null;
    }
};

pub const Value = struct {
    const Self = @This();

    handle: *const c.Value,

    pub fn toString(self: Self, ctx: Context) String {
        return .{
            .handle = c.v8__Value__ToString(self.handle, ctx.handle).?,
        };
    }

    pub fn toU32(self: Self, ctx: Context) u32 {
        var out: c.MaybeU32 = undefined;
        c.v8__Value__Uint32Value(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return out.value;
        } else {
            return 0;
        }
    }
};