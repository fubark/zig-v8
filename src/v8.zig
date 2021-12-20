const std = @import("std");

const c = @cImport({
    @cInclude("binding.h");
});

pub const PropertyAttribute = struct {
    pub const None = c.None;
    pub const ReadOnly = c.ReadOnly;
};

// Currently, user callback functions passed into FunctionTemplate will need to have this declared as a param and then
// converted to FunctionCallbackInfo to get a nicer interface.
pub const C_FunctionCallbackInfo = c.FunctionCallbackInfo;
pub const C_PropertyCallbackInfo = c.PropertyCallbackInfo;
pub const C_WeakCallbackInfo = c.WeakCallbackInfo;

pub const FunctionCallback = c.FunctionCallback;
pub const AccessorNameGetterCallback = c.AccessorNameGetterCallback;
pub const AccessorNameSetterCallback = c.AccessorNameSetterCallback;

pub const Name = c.Name;

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

pub const Exception = struct {

    pub fn initError(msg: String) Value {
        return .{
            .handle = c.v8__Exception__Error(msg.handle).?,
        };
    }
};

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

    /// It seems stack trace is only captured if the value is wrapped in an Exception.initError.
    pub fn throwException(self: Self, value: anytype) Value {
        return .{
            .handle = c.v8__Isolate__ThrowException(self.handle, getValueHandle(value)).?,
        };
    }

};

pub const HandleScope = struct {
    const Self = @This();

    inner: c.HandleScope,

    /// [Notes]
    /// This starts a new stack frame to record local objects created.
    pub fn init(self: *Self, isolate: Isolate) void {
        c.v8__HandleScope__CONSTRUCT(&self.inner, isolate.handle);
    }

    /// [Notes]
    /// This pops the scope frame and allows V8 to mark/free local objects created since HandleScope.init.
    /// In C++ code, this would happen automatically when the HandleScope var leaves the current scope.
    pub fn deinit(self: *Self) void {
        c.v8__HandleScope__DESTRUCT(&self.inner);
    }
};

pub const Context = struct {
    const Self = @This();

    handle: *const c.Context,

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
    pub fn enter(self: Self) void {
        c.v8__Context__Enter(self.handle);
    }

    /// [V8]
    /// Exit this context.  Exiting the current context restores the
    /// context that was in place when entering the current context.
    pub fn exit(self: Self) void {
        c.v8__Context__Exit(self.handle);
    }

    /// [V8]
    /// Returns the isolate associated with a current context.
    pub fn getIsolate(self: Self) *Isolate {
        return c.v8__Context__GetIsolate(self);
    }

    pub fn getGlobal(self: Self) Object {
        return .{
            .handle = c.v8__Context__Global(self.handle).?,
        };
    }
};

pub const PropertyCallbackInfo = struct {
    const Self = @This();

    handle: *const c.PropertyCallbackInfo,

    pub fn initFromV8(val: ?*const c.PropertyCallbackInfo) Self {
        return .{
            .handle = val.?,
        };
    }

    pub fn getIsolate(self: Self) Isolate {
        return .{
            .handle = c.v8__PropertyCallbackInfo__GetIsolate(self.handle).?,
        };
    }

    pub fn getReturnValue(self: Self) ReturnValue {
        var res: c.ReturnValue = undefined;
        c.v8__PropertyCallbackInfo__GetReturnValue(self.handle, &res);
        return .{
            .inner = res,
        };
    }

    pub fn getThis(self: Self) Object {
        return .{
            .handle = c.v8__PropertyCallbackInfo__This(self.handle).?,
        };
    }
};

pub const WeakCallbackInfo = struct {
    const Self = @This();

    handle: *const c.WeakCallbackInfo,

    pub fn initFromC(val: ?*const c.WeakCallbackInfo) Self {
        return .{
            .handle = val.?,
        };
    }

    pub fn getIsolate(self: Self) Isolate {
        return .{
            .handle = c.v8__WeakCallbackInfo__GetIsolate(self.handle).?,
        };
    }

    pub fn getParameter(self: Self) *const c_void {
        return c.v8__WeakCallbackInfo__GetParameter(self.handle).?;
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

    pub fn getThis(self: Self) Object {
        return .{
            .handle = c.v8__FunctionCallbackInfo__This(self.handle).?,
        };
    }
};

pub const ReturnValue = struct {
    const Self = @This();

    inner: c.ReturnValue,

    pub fn set(self: Self, value: anytype) void {
        c.v8__ReturnValue__Set(self.inner, getValueHandle(value));
    }

    pub fn setValueHandle(self: Self, ptr: *const c.Value) void {
        c.v8__ReturnValue__Set(self.inner, ptr);
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

    pub fn initDefault(isolate: Isolate) Self {
        return .{
            .handle = c.v8__FunctionTemplate__New__DEFAULT(isolate.handle).?,
        };
    }

    pub fn initCallback(isolate: Isolate, callback: c.FunctionCallback) Self {
        return .{
            .handle = c.v8__FunctionTemplate__New__DEFAULT2(isolate.handle, callback).?,
        };
    }

    /// This is typically used to set class fields.
    pub fn getInstanceTemplate(self: Self) ObjectTemplate {
        return .{
            .handle = c.v8__FunctionTemplate__InstanceTemplate(self.handle).?,
        };
    }

    /// This is typically used to set class methods.
    pub fn getPrototypeTemplate(self: Self) ObjectTemplate {
        return .{
            .handle = c.v8__FunctionTemplate__PrototypeTemplate(self.handle).?,
        };
    }

    /// There is only one unique function for a FunctionTemplate in a given context.
    /// The Function can then be used to invoke NewInstance which is equivalent to doing js "new".
    pub fn getFunction(self: Self, ctx: Context) Function {
        return .{
            .handle = c.v8__FunctionTemplate__GetFunction(self.handle, ctx.handle).?,
        };
    }

    /// Sets static property on the template.
    pub fn set(self: Self, key: anytype, value: anytype, attr: c.PropertyAttribute) void {
        c.v8__Template__Set(getTemplateHandle(self), getNameHandle(key), getDataHandle(value), attr);
    }

    pub fn setGetter(self: Self, name: anytype, getter: FunctionTemplate) void {
        c.v8__Template__SetAccessorProperty__DEFAULT(getTemplateHandle(self), getNameHandle(name), getter.handle);
    }

    pub fn setClassName(self: Self, name: String) void {
        c.v8__FunctionTemplate__SetClassName(self.handle, name.handle);
    }

    pub fn setReadOnlyPrototype(self: Self) void {
        c.v8__FunctionTemplate__ReadOnlyPrototype(self.handle);
    }
};

pub const Function = struct {
    const Self = @This();

    handle: *const c.Function,

    /// receiver_val is "this" in the function context. This is equivalent to calling fn.apply(receiver, args) in JS.
    /// Returns null if there was an error.
    pub fn call(self: Self, ctx: Context, receiver_val: anytype, args: []const Value) ?Value {
        const c_args = @ptrCast(?[*]const ?*c_void, args.ptr);
        if (c.v8__Function__Call(self.handle, ctx.handle, getValueHandle(receiver_val), @intCast(c_int, args.len), c_args)) |ret| {
            return Value{
                .handle = ret,
            };
        } else return null;
    }

    // Equavalent to js "new".
    pub fn initInstance(self: Self, ctx: Context, args: []const Value) ?Object {
        const c_args = @ptrCast(?[*]const ?*c_void, args.ptr);
        if (c.v8__Function__NewInstance(self.handle, ctx.handle, @intCast(c_int, args.len), c_args)) |ret| {
            return Object{
                .handle = ret,
            };
        } else return null;
    }

    pub fn toObject(self: Self) Object {
        return .{
            .handle = @ptrCast(*const c.Object, self.handle),
        };
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }

    /// Should only be called if you know the underlying type is a v8.Persistent.
    pub fn castToPersistent(self: Self) Persistent {
        return .{
            .handle = self.handle,
        };
    }
};

pub const Persistent = struct {
    const Self = @This();

    // The Persistent handle is just like other value handles for easy casting. 
    // But when creating and operating on it, an indirect pointer is used to represent a c.Persistent struct (v8::Persistent<v8::Value> in C++).
    handle: *const c_void,

    /// A new value is created that references the original value.
    pub fn init(isolate: Isolate, value: anytype) Self {
        var handle: *c_void = undefined;
        c.v8__Persistent__New(isolate.handle, getValueHandle(value), @ptrCast(*c.Persistent, &handle));
        return .{
            .handle = handle,
        };
    }

    pub fn deinit(self: *Self) void {
        c.v8__Persistent__Reset(@ptrCast(*c.Persistent, &self.handle));
    }

    /// Should only be called if you know the underlying type is a v8.Function.
    pub fn castToFunction(self: Self) Function {
        return .{
            .handle = @ptrCast(*const c.Function, self.handle),
        };
    }

    /// Should only be called if you know the underlying type is a v8.Object.
    pub fn castToObject(self: Self) Object {
        return .{
            .handle = @ptrCast(*const c.Object, self.handle),
        };
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }

    pub fn setWeak(self: *Self) void {
        c.v8__Persistent__SetWeak(@ptrCast(*c.Persistent, &self.handle));
    }

    pub fn setWeakFinalizer(self: *Self, finalizer_ctx: *c_void, cb: c.WeakCallback, cb_type: c.WeakCallbackType) void {
        c.v8__Persistent__SetWeakFinalizer(
            @ptrCast(*c.Persistent, &self.handle),
            finalizer_ctx, cb, cb_type
        );
    }
};

/// [V8]
/// kParameter will pass a void* parameter back to the callback, kInternalFields
/// will pass the first two internal fields back to the callback, kFinalizer
/// will pass a void* parameter back, but is invoked before the object is
/// actually collected, so it can be resurrected. In the last case, it is not
/// possible to request a second pass callback.
pub const WeakCallbackType = struct {
    pub const kParameter = c.kParameter;
    pub const kInternalFields = c.kInternalFields;
    pub const kFinalizer = c.kFinalizer;
};

pub const ObjectTemplate = struct {
    const Self = @This();

    handle: *const c.ObjectTemplate,

    pub fn initDefault(isolate: Isolate) Self {
        return .{
            .handle = c.v8__ObjectTemplate__New__DEFAULT(isolate.handle).?,
        };
    }

    pub fn init(isolate: Isolate, constructor: FunctionTemplate) Self {
        return .{
            .handle = c.v8__ObjectTemplate__New(isolate.handle, constructor.handle).?,
        };
    }

    pub fn initInstance(self: Self, ctx: Context) Object {
        return .{
            .handle = c.v8__ObjectTemplate__NewInstance(self.handle, ctx.handle).?,
        };
    }

    pub fn setGetter(self: Self, name: anytype, getter: c.AccessorNameGetterCallback) void {
        c.v8__ObjectTemplate__SetAccessor__DEFAULT(self.handle, getNameHandle(name), getter);
    }

    pub fn setGetterAndSetter(self: Self, name: anytype, getter: c.AccessorNameGetterCallback, setter: c.AccessorNameSetterCallback) void {
        c.v8__ObjectTemplate__SetAccessor__DEFAULT2(self.handle, getNameHandle(name), getter, setter);
    }

    pub fn set(self: Self, key: anytype, value: anytype, attr: c.PropertyAttribute) void {
        c.v8__Template__Set(getTemplateHandle(self), getNameHandle(key), getDataHandle(value), attr);
    }

    pub fn setInternalFieldCount(self: Self, count: u32) void {
        c.v8__ObjectTemplate__SetInternalFieldCount(self.handle, @intCast(c_int, count));
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }
};

pub const Array = struct {
    const Self = @This();

    handle: *const c.Array,

    pub fn length(self: Self) u32 {
        return c.v8__Array__Length(self.handle);
    }
};

pub const Object = struct {
    const Self = @This();

    handle: *const c.Object,

    pub fn init(isolate: Isolate) Self {
        return .{
            .handle = c.v8__Object__New(isolate.handle).?,
        };
    }

    pub fn setInternalField(self: Self, idx: u32, value: anytype) void {
        c.v8__Object__SetInternalField(self.handle, @intCast(c_int, idx), getValueHandle(value));
    }

    pub fn getInternalField(self: Self, idx: u32) Value {
        return .{
            .handle = c.v8__Object__GetInternalField(self.handle, @intCast(c_int, idx)).?,
        };
    }

    // Returns true on success, false on fail.
    pub fn setValue(self: Self, ctx: Context, key: anytype, value: anytype) bool {
        var out: c.MaybeBool = undefined;
        c.v8__Object__Set(self.handle, ctx.handle, getValueHandle(key), getValueHandle(value), &out);
        // Set only returns empty for an error or true.
        return out.has_value == 1;
    }

    pub fn getValue(self: Self, ctx: Context, key: anytype) Value {
        return .{
            .handle = c.v8__Object__Get(self.handle, ctx.handle, getValueHandle(key)).?,
        };
    }

    pub fn getAtIndex(self: Self, ctx: Context, idx: u32) Value {
        return .{
            .handle = c.v8__Object__GetIndex(self.handle, ctx.handle, idx).?,
        };
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }

    pub fn defineOwnProperty(self: Self, ctx: Context, name: anytype, value: anytype, attr: c.PropertyAttribute) ?bool {
        var out: c.MaybeBool = undefined;
        c.v8__Object__DefineOwnProperty(self.handle, ctx.handle, getNameHandle(name), getValueHandle(value), attr, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return null;
    }
};

pub const Number = struct {
    const Self = @This();

    handle: *const c.Number,

    pub fn init(isolate: Isolate, val: f64) Self {
        return .{
            .handle = c.v8__Number__New(isolate.handle, val).?,
        };
    }

    pub fn initBitCastedU64(isolate: Isolate, val: u64) Self {
        return init(isolate, @bitCast(f64, val));
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }
};

pub const Integer = struct {
    const Self = @This();

    handle: *const c.Integer,

    pub fn initI32(isolate: Isolate, val: i32) Self {
        return .{
            .handle = c.v8__Integer__New(isolate.handle, val).?,
        };
    }

    pub fn initU32(isolate: Isolate, val: u32) Self {
        return .{
            .handle = c.v8__Integer__NewFromUnsigned(isolate.handle, val).?,
        };
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }
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
        Integer => val.handle,
        Primitive => val.handle,
        Number => val.handle,
        Function => val.handle,
        Persistent => val.handle,
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
        FunctionTemplate => val.handle,
        ObjectTemplate => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Template", .{@typeName(@TypeOf(val))})),
    });
}

inline fn getDataHandle(val: anytype) *const c.Data {
    return @ptrCast(*const c.Data, comptime switch (@TypeOf(val)) {
        FunctionTemplate => val.handle,
        ObjectTemplate => val.handle,
        Integer => val.handle,
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

pub const Boolean = struct {
    const Self = @This();

    handle: *const c.Boolean,

    pub fn init(isolate: Isolate, val: bool) Self {
        return .{
            .handle = c.v8__Boolean__New(isolate.handle, val).?,
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
        return @intCast(u32, c.v8__String__Utf8Length(self.handle, isolate.handle));
    }

    pub fn writeUtf8(self: String, isolate: Isolate, buf: []const u8) u32 {
        const options = c.NO_NULL_TERMINATION | c.REPLACE_INVALID_UTF8;
        // num chars is how many utf8 characters are actually written and the function returns how many bytes were written.
        var nchars: c_int = 0;
        // TODO: Return num chars
        return @intCast(u32, c.v8__String__WriteUtf8(self.handle, isolate.handle, buf.ptr, @intCast(c_int, buf.len), &nchars, options));
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
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

    pub fn toBool(self: Self, isolate: Isolate) bool {
        return c.v8__Value__BooleanValue(self.handle, isolate.handle);
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

    pub fn toF32(self: Self, ctx: Context) f32 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return @floatCast(f32, out.value);
        } else {
            return 0;
        }
    }

    pub fn toF64(self: Self, ctx: Context) f64 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return out.value;
        } else {
            return 0;
        }
    }

    pub fn bitCastToU64(self: Self, ctx: Context) u64 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return @bitCast(u64, out.value);
        } else {
            return 0;
        }
    }

    pub fn instanceOf(self: Self, ctx: Context, obj: Object) bool {
        var out: c.MaybeBool = undefined;
        c.v8__Value__InstanceOf(self.handle, ctx.handle, obj.handle, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return false;
    }

    pub fn isObject(self: Self) bool {
        return c.v8__Value__IsObject(self.handle);
    }

    pub fn isFunction(self: Self) bool {
        return c.v8__Value__IsFunction(self.handle);
    }

    pub fn isArray(self: Self) bool {
        return c.v8__Value__IsArray(self.handle);
    }

    /// Should only be called if you know the underlying type is a v8.Function.
    pub fn castToFunction(self: Self) Function {
        return .{
            .handle = @ptrCast(*const c.Function, self.handle),
        };
    }

    /// Should only be called if you know the underlying type is a v8.Object.
    pub fn castToObject(self: Self) Object {
        return .{
            .handle = @ptrCast(*const c.Object, self.handle),
        };
    }

    /// Should only be called if you know the underlying type is a v8.Array.
    pub fn castToArray(self: Self) Array {
        return .{
            .handle = @ptrCast(*const c.Array, self.handle),
        };
    }
};

pub const Primitive = struct {
    const Self = @This();

    handle: *const c.Primitive,
};

pub fn initUndefined(isolate: Isolate) Primitive {
    return .{
        .handle = c.v8__Undefined(isolate.handle).?,
    };
}

pub fn initTrue(isolate: Isolate) Boolean {
    return .{
        .handle = c.v8__True(isolate.handle).?,
    };
}

pub fn initFalse(isolate: Isolate) Boolean {
    return .{
        .handle = c.v8__False(isolate.handle).?,
    };
}