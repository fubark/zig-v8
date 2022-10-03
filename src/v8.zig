const std = @import("std");

const c = @cImport({
    @cInclude("binding.h");
});

pub const PropertyAttribute = struct {
    pub const None = c.None;
    pub const ReadOnly = c.ReadOnly;
};

pub const PromiseRejectEvent = struct {
    pub const kPromiseRejectWithNoHandler = c.kPromiseRejectWithNoHandler;
    pub const kPromiseHandlerAddedAfterReject = c.kPromiseHandlerAddedAfterReject;
    pub const kPromiseRejectAfterResolved = c.kPromiseRejectAfterResolved;
    pub const kPromiseResolveAfterResolved = c.kPromiseResolveAfterResolved;
};

pub const MessageErrorLevel = struct {
    pub const kMessageLog = c.kMessageLog;
    pub const kMessageDebug = c.kMessageDebug;
    pub const kMessageInfo = c.kMessageInfo;
    pub const kMessageError = c.kMessageError;
    pub const kMessageWarning = c.kMessageWarning;
    pub const kMessageAll = c.kMessageAll;
};

/// [V8]
/// Policy for running microtasks:
/// - explicit: microtasks are invoked with the
///     Isolate::PerformMicrotaskCheckpoint() method;
/// - scoped: microtasks invocation is controlled by MicrotasksScope objects;
/// - auto: microtasks are invoked when the script call depth decrements to zero.
pub const MicrotasksPolicy = struct {
    pub const kExplicit = c.kExplicit;
    pub const kScoped = c.kScoped;
    pub const kAuto = c.kAuto;
};

// Currently, user callback functions passed into FunctionTemplate will need to have this declared as a param and then
// converted to FunctionCallbackInfo to get a nicer interface.
pub const C_FunctionCallbackInfo = c.FunctionCallbackInfo;
pub const C_PropertyCallbackInfo = c.PropertyCallbackInfo;
pub const C_WeakCallbackInfo = c.WeakCallbackInfo;
pub const C_PromiseRejectMessage = c.PromiseRejectMessage;

pub const C_Message = c.Message;
pub const C_Value = c.Value;
pub const C_Context = c.Context;
pub const C_Data = c.Data;
pub const C_FixedArray = c.FixedArray;
pub const C_Module = c.Module;
pub const C_InternalAddress = c.InternalAddress;

pub const MessageCallback = c.MessageCallback;
pub const FunctionCallback = c.FunctionCallback;
pub const AccessorNameGetterCallback = c.AccessorNameGetterCallback;
pub const AccessorNameSetterCallback = c.AccessorNameSetterCallback;

pub const CreateParams = c.CreateParams;

pub const Name = c.Name;

pub const SharedPtr = c.SharedPtr;

const Root = @This();

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
        assert(@sizeOf(c.PromiseRejectMessage) == c.v8__PromiseRejectMessage__SIZEOF());
        assert(@sizeOf(c.ScriptCompilerSource) == c.v8__ScriptCompiler__Source__SIZEOF());
        assert(@sizeOf(c.ScriptCompilerCachedData) == c.v8__ScriptCompiler__CachedData__SIZEOF());
        assert(@sizeOf(c.HeapStatistics) == c.v8__HeapStatistics__SIZEOF());
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

/// [v8]
/// Sets the v8::Platform to use. This should be invoked before V8 is
/// initialized.
pub fn initV8Platform(platform: Platform) void {
    c.v8__V8__InitializePlatform(platform.handle);
}

/// [v8]
/// Initializes V8. This function needs to be called before the first Isolate
/// is created. It always returns true.
pub fn initV8() void {
    c.v8__V8__Initialize();
}

/// [v8]
/// Releases any resources used by v8 and stops any utility thread
/// that may be running.  Note that disposing v8 is permanent, it
/// cannot be reinitialized.
///
/// It should generally not be necessary to dispose v8 before exiting
/// a process, this should happen automatically.  It is only necessary
/// to use if the process needs the resources taken up by v8.
pub fn deinitV8() bool {
    return c.v8__V8__Dispose() == 1;
}

/// [v8]
/// Clears all references to the v8::Platform. This should be invoked after
/// V8 was disposed.
pub fn deinitV8Platform() void {
    c.v8__V8__DisposePlatform();
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

    pub fn initTypeError(msg: String) Value {
        return .{
            .handle = c.v8__Exception__TypeError(msg.handle).?,
        };
    }

    pub fn initSyntaxError(msg: String) Value {
        return .{
            .handle = c.v8__Exception__SyntaxError(msg.handle).?,
        };
    }

    pub fn initReferenceError(msg: String) Value {
        return .{
            .handle = c.v8__Exception__ReferenceError(msg.handle).?,
        };
    }

    pub fn initRangeError(msg: String) Value {
        return .{
            .handle = c.v8__Exception__RangeError(msg.handle).?,
        };
    }

    pub fn initMessage(iso: Isolate, exception: Value) Message {
        return .{
            .handle = c.v8__Exception__CreateMessage(iso.handle, exception.handle).?,
        };
    }

    /// [v8]
    /// Returns the original stack trace that was captured at the creation time
    /// of a given exception, or an empty handle if not available.
    pub fn getStackTrace(exception: Value) ?StackTrace {
        if (c.v8__Exception__GetStackTrace(exception.handle)) |handle| {
            return StackTrace{
                .handle = handle,
            };
        } else return null;
    }
};

/// Contains Isolate related methods and convenience methods for creating js values.
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

    /// [V8]
    /// Set callback to notify about promise reject with no handler, or
    /// revocation of such a previous notification once the handler is added.
    pub fn setPromiseRejectCallback(self: Self, callback: c.PromiseRejectCallback) void {
        c.v8__Isolate__SetPromiseRejectCallback(self.handle, callback);
    }

    pub fn getMicrotasksPolicy(self: Self) c.MicrotasksPolicy {
        return c.v8__Isolate__GetMicrotasksPolicy(self.handle);
    }

    pub fn setMicrotasksPolicy(self: Self, policy: c.MicrotasksPolicy) void {
        c.v8__Isolate__SetMicrotasksPolicy(self.handle, policy);
    }

    pub fn performMicrotasksCheckpoint(self: Self) void {
        c.v8__Isolate__PerformMicrotaskCheckpoint(self.handle);
    }

    pub fn addMessageListener(self: Self, callback: c.MessageCallback) bool {
        return c.v8__Isolate__AddMessageListener(self.handle, callback);
    }

    pub fn addMessageListenerWithErrorLevel(self: Self, callback: c.MessageCallback, message_levels: c_int, value: Value) bool {
        return c.v8__Isolate__AddMessageListenerWithErrorLevel(self.handle, callback, message_levels, value.handle);
    }

    /// [v8]
    /// Tells V8 to capture current stack trace when uncaught exception occurs
    /// and report it to the message listeners. The option is off by default.
    pub fn setCaptureStackTraceForUncaughtExceptions(self: Self, capture: bool, frame_limit: u32) void {
        c.v8__Isolate__SetCaptureStackTraceForUncaughtExceptions(self.handle, capture, @intCast(c_int, frame_limit));
    }

    /// This does not terminate the current script immediately. V8 will mark it for termination at a later time. This was intended to end long running loops.
    pub fn terminateExecution(self: Self) void {
        c.v8__Isolate__TerminateExecution(self.handle);
    }

    pub fn isExecutionTerminating(self: Self) bool {
        return c.v8__Isolate__IsExecutionTerminating(self.handle);
    }

    pub fn cancelTerminateExecution(self: Self) void {
        c.v8__Isolate__CancelTerminateExecution(self.handle);
    }

    pub fn lowMemoryNotification(self: Self) void {
        c.v8__Isolate__LowMemoryNotification(self.handle);
    }

    pub fn getHeapStatistics(self: Self) c.HeapStatistics {
        var res: c.HeapStatistics = undefined;
        c.v8__Isolate__GetHeapStatistics(self.handle, &res);
        return res;
    }

    pub fn initNumber(self: Self, val: f64) Number {
        return Number.init(self, val);
    }

    pub fn initNumberBitCastedU64(self: Self, val: u64) Number {
        return Number.initBitCastedU64(self, val);
    }

    pub fn initBoolean(self: Self, val: bool) Boolean {
        return Boolean.init(self, val);
    }

    pub fn initIntegerI32(self: Self, val: i32) Integer {
        return Integer.initI32(self, val);
    }

    pub fn initIntegerU32(self: Self, val: u32) Integer {
        return Integer.initU32(self, val);
    }

    pub fn initBigIntI64(self: Self, val: i64) BigInt {
        return BigInt.initI64(self, val);
    }

    pub fn initBigIntU64(self: Self, val: u64) BigInt {
        return BigInt.initU64(self, val);
    }

    pub fn initStringUtf8(self: Self, val: []const u8) String {
        return String.initUtf8(self, val);
    }

    pub fn initPersistent(self: Self, comptime T: type, val: T) Persistent(T) {
        return Persistent(T).init(self, val);
    }

    pub fn initFunctionTemplateDefault(self: Self) FunctionTemplate {
        return FunctionTemplate.initDefault(self);
    }

    pub fn initFunctionTemplateCallback(self: Self, callback: c.FunctionCallback) FunctionTemplate {
        return FunctionTemplate.initCallback(self, callback);
    }

    pub fn initFunctionTemplateCallbackData(self: Self, callback: c.FunctionCallback, data_value: anytype) FunctionTemplate {
        return FunctionTemplate.initCallbackData(self, callback, data_value);
    }

    pub fn initObjectTemplateDefault(self: Self) ObjectTemplate {
        return ObjectTemplate.initDefault(self);
    }

    pub fn initObjectTemplate(self: Self, constructor: FunctionTemplate) ObjectTemplate {
        return ObjectTemplate.init(self, constructor);
    }

    pub fn initObject(self: Self) Object {
        return Object.init(self);
    }

    pub fn initArray(self: Self, len: u32) Array {
        return Array.init(self, len);
    }

    pub fn initArrayElements(self: Self, elems: []const Value) Array {
        return Array.initElements(self, elems);
    }

    pub fn initUndefined(self: Self) Primitive {
        return Root.initUndefined(self);
    }

    pub fn initNull(self: Self) Primitive {
        return Root.initNull(self);
    }

    pub fn initTrue(self: Self) Boolean {
        return Root.initTrue(self);
    }

    pub fn initFalse(self: Self) Boolean {
        return Root.initFalse(self);
    }

    pub fn initContext(self: Self, global_tmpl: ?ObjectTemplate, global_obj: ?*c.Value) Context {
        return Context.init(self, global_tmpl, global_obj);
    }

    pub fn initExternal(self: Self, val: ?*anyopaque) External {
        return External.init(self, val);
    }
};

pub const HandleScope = struct {
    const Self = @This();

    inner: c.HandleScope,

    /// [Notes]
    /// This starts a new stack frame to record local objects created.
    /// Since deinit depends on the inner pointer being the same, init should construct in place.
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
            .handle = c.v8__Context__New(isolate.handle, if (global_tmpl != null) global_tmpl.?.handle else null, global_obj).?,
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
    pub fn getIsolate(self: Self) Isolate {
        return Isolate{
            .handle = c.v8__Context__GetIsolate(self.handle).?,
        };
    }

    pub fn getGlobal(self: Self) Object {
        return .{
            .handle = c.v8__Context__Global(self.handle).?,
        };
    }

    pub fn getEmbedderData(self: Self, idx: u32) Value {
        return .{
            .handle = c.v8__Context__GetEmbedderData(self.handle, @intCast(c_int, idx)).?,
        };
    }

    pub fn setEmbedderData(self: Self, idx: u32, val: anytype) void {
        c.v8__Context__SetEmbedderData(self.handle, @intCast(c_int, idx), getValueHandle(val));
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

    pub fn getData(self: Self) Value {
        return .{
            .handle = c.v8__PropertyCallbackInfo__Data(self.handle).?,
        };
    }

    pub fn getExternalValue(self: Self) ?*anyopaque {
        return self.getData().castTo(External).get();
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

    pub fn getParameter(self: Self) *anyopaque {
        return c.v8__WeakCallbackInfo__GetParameter(self.handle).?;
    }

    pub fn getInternalField(self: Self, idx: u32) ?*anyopaque {
        return c.v8__WeakCallbackInfo__GetInternalField(self.handle, @intCast(c_int, idx));
    }
};

pub const PromiseRejectMessage = struct {
    const Self = @This();

    inner: c.PromiseRejectMessage,

    pub fn initFromC(val: c.PromiseRejectMessage) Self {
        return .{
            .inner = val,
        };
    }

    pub fn getEvent(self: Self) c.PromiseRejectEvent {
        return c.v8__PromiseRejectMessage__GetEvent(&self.inner);
    }

    pub fn getPromise(self: Self) Promise {
        return .{
            .handle = c.v8__PromiseRejectMessage__GetPromise(&self.inner).?,
        };
    }

    pub fn getValue(self: Self) Value {
        return .{
            .handle = c.v8__PromiseRejectMessage__GetValue(&self.inner).?,
        };
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

    pub fn getData(self: Self) Value {
        return .{
            .handle = c.v8__FunctionCallbackInfo__Data(self.handle).?,
        };
    }

    pub fn getExternalValue(self: Self) ?*anyopaque {
        return self.getData().castTo(External).get();
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

    pub fn initCallbackData(isolate: Isolate, callback: c.FunctionCallback, data_val: anytype) Self {
        return .{
            .handle = c.v8__FunctionTemplate__New__DEFAULT3(isolate.handle, callback, getValueHandle(data_val)).?,
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

    /// Internally, this will create a temporary FunctionTemplate to get a new Function instance.
    pub fn initDefault(ctx: Context, callback: c.FunctionCallback) Self {
        return .{
            .handle = c.v8__Function__New__DEFAULT(ctx.handle, callback).?,
        };
    }

    pub fn initWithData(ctx: Context, callback: c.FunctionCallback, data_val: anytype) Self {
        return .{
            .handle = c.v8__Function__New__DEFAULT2(ctx.handle, callback, getValueHandle(data_val)).?,
        };
    }

    /// receiver_val is "this" in the function context. This is equivalent to calling fn.apply(receiver, args) in JS.
    /// Returns null if there was an error.
    pub fn call(self: Self, ctx: Context, receiver_val: anytype, args: []const Value) ?Value {
        const c_args = @ptrCast(?[*]const ?*c.Value, args.ptr);
        if (c.v8__Function__Call(self.handle, ctx.handle, getValueHandle(receiver_val), @intCast(c_int, args.len), c_args)) |ret| {
            return Value{
                .handle = ret,
            };
        } else return null;
    }

    // Equavalent to js "new".
    pub fn initInstance(self: Self, ctx: Context, args: []const Value) ?Object {
        const c_args = @ptrCast(?[*]const ?*c.Value, args.ptr);
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

    pub fn getName(self: Self) Value {
        return .{
            .handle = c.v8__Function__GetName(self.handle).?,
        };
    }

    pub fn setName(self: Self, name: String) void {
        c.v8__Function__SetName(self.handle, name.handle);
    }
};

pub fn Persistent(comptime T: type) type {
    return struct {
        const Self = @This();

        inner: T,

        /// A new value is created that references the original value.
        /// A Persistent handle is a pointer just like any other value handles,
        /// but when creating and operating on it, an indirect pointer is used to represent a c.Persistent struct (v8::Persistent<v8::Value> in C++).
        pub fn init(isolate: Isolate, data: T) Self {
            var handle: *c.Data = undefined;
            c.v8__Persistent__New(isolate.handle, getDataHandle(data), @ptrCast(*c.Persistent, &handle));
            return .{
                .inner = .{
                    .handle = @ptrCast(@TypeOf(data.handle), handle),
                },
            };
        }

        pub fn deinit(self: *Self) void {
            c.v8__Persistent__Reset(@ptrCast(*c.Persistent, &self.inner.handle));
        }

        pub fn setWeak(self: *Self) void {
            c.v8__Persistent__SetWeak(@ptrCast(*c.Persistent, &self.inner.handle));
        }

        /// An external pointer can be set when cb_type is kParameter or kInternalFields.
        /// When cb_type is kInternalFields, the object fields are expected to be set with setAlignedPointerInInternalField.
        /// The pointer value must be a multiple of 2 due to how v8 encodes the pointers.
        pub fn setWeakFinalizer(self: *Self, finalizer_ctx: *anyopaque, cb: c.WeakCallback, cb_type: WeakCallbackType) void {
            c.v8__Persistent__SetWeakFinalizer(@ptrCast(*c.Persistent, &self.inner.handle), finalizer_ctx, cb, @enumToInt(cb_type));
        }

        /// Should only be called if you know the underlying type is a v8.Function.
        pub fn castToFunction(self: Self) Function {
            return .{
                .handle = @ptrCast(*const c.Function, self.inner.handle),
            };
        }

        /// Should only be called if you know the underlying type is a v8.Object.
        pub fn castToObject(self: Self) Object {
            return .{
                .handle = @ptrCast(*const c.Object, self.inner.handle),
            };
        }

        /// Should only be called if you know the underlying type is a v8.PromiseResolver.
        pub fn castToPromiseResolver(self: Self) PromiseResolver {
            return .{
                .handle = @ptrCast(*const c.PromiseResolver, self.inner.handle),
            };
        }

        pub fn toValue(self: Self) Value {
            return .{
                .handle = self.inner.handle,
            };
        }
    };
}

/// [V8]
/// kParameter will pass a void* parameter back to the callback, kInternalFields
/// will pass the first two internal fields back to the callback, kFinalizer
/// will pass a void* parameter back, but is invoked before the object is
/// actually collected, so it can be resurrected. In the last case, it is not
/// possible to request a second pass callback.
pub const WeakCallbackType = enum(u32) {
    kParameter = c.kParameter,
    kInternalFields = c.kInternalFields,
    kFinalizer = c.kFinalizer,
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

    pub fn init(iso: Isolate, len: u32) Self {
        return .{
            .handle = c.v8__Array__New(iso.handle, @intCast(c_int, len)).?,
        };
    }

    pub fn initElements(iso: Isolate, elems: []const Value) Self {
        const c_elems = @ptrCast(?[*]const ?*c.Value, elems.ptr);
        return .{
            .handle = c.v8__Array__New2(iso.handle, c_elems, elems.len).?,
        };
    }

    pub fn length(self: Self) u32 {
        return c.v8__Array__Length(self.handle);
    }

    pub fn castTo(self: Self, comptime T: type) T {
        switch (T) {
            Object => {
                return .{
                    .handle = @ptrCast(*const c.Object, self.handle),
                };
            },
            else => unreachable,
        }
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

    pub fn setAlignedPointerInInternalField(self: Self, idx: u32, ptr: ?*anyopaque) void {
        c.v8__Object__SetAlignedPointerInInternalField(self.handle, @intCast(c_int, idx), ptr);
    }

    // Returns true on success, false on fail.
    pub fn setValue(self: Self, ctx: Context, key: anytype, value: anytype) bool {
        var out: c.MaybeBool = undefined;
        c.v8__Object__Set(self.handle, ctx.handle, getValueHandle(key), getValueHandle(value), &out);
        // Set only returns empty for an error or true.
        return out.has_value == 1;
    }

    pub fn getValue(self: Self, ctx: Context, key: anytype) !Value {
        if (c.v8__Object__Get(self.handle, ctx.handle, getValueHandle(key))) |handle| {
            return Value{
                .handle = handle,
            };
        } else return error.JsException;
    }

    pub fn getAtIndex(self: Self, ctx: Context, idx: u32) !Value {
        if (c.v8__Object__GetIndex(self.handle, ctx.handle, idx)) |handle| {
            return Value{
                .handle = handle,
            };
        } else return error.JsException;
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

    pub fn getIsolate(self: Self) Isolate {
        return .{
            .handle = c.v8__Object__GetIsolate(self.handle).?,
        };
    }

    pub fn getCreationContext(self: Self) Context {
        return .{
            .handle = c.v8__Object__GetCreationContext(self.handle).?,
        };
    }

    pub fn getIdentityHash(self: Self) u32 {
        return @bitCast(u32, c.v8__Object__GetIdentityHash(self.handle));
    }

    pub fn has(self: Self, ctx: Context, key: Value) bool {
        var out: c.MaybeBool = undefined;
        c.v8__Object__Has(self.handle, ctx.handle, key.handle, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return false;
    }

    pub fn hasIndex(self: Self, ctx: Context, idx: u32) bool {
        var out: c.MaybeBool = undefined;
        c.v8__Object__Has(self.handle, ctx.handle, idx, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return false;
    }

    pub fn getOwnPropertyNames(self: Self, ctx: Context) Array {
        return .{
            .handle = c.v8__Object__GetOwnPropertyNames(self.handle, ctx.handle).?,
        };
    }

    pub fn getPropertyNames(self: Self, ctx: Context) Array {
        return .{
            .handle = c.v8__Object__GetPropertyNames(self.handle, ctx.handle).?,
        };
    }
};

pub const External = struct {
    const Self = @This();

    handle: *const c.External,

    pub fn init(isolate: Isolate, val: ?*anyopaque) Self {
        return .{
            .handle = c.v8__External__New(isolate.handle, val).?,
        };
    }

    pub fn get(self: Self) ?*anyopaque {
        return c.v8__External__Value(self.handle);
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
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

    pub fn getValue(self: Self) u64 {
        return c.v8__Integer__Value(self.handle);
    }

    pub fn getValueU32(self: Self) u32 {
        return @intCast(u32, c.v8__Integer__Value(self.handle));
    }

    pub fn toValue(self: Self) Value {
        return .{
            .handle = self.handle,
        };
    }
};

pub const BigInt = struct {
    const Self = @This();

    handle: *const c.Integer,

    pub fn initI64(iso: Isolate, val: i64) Self {
        return .{
            .handle = c.v8__BigInt__New(iso.handle, val).?,
        };
    }

    pub fn initU64(iso: Isolate, val: u64) Self {
        return .{
            .handle = c.v8__BigInt__NewFromUnsigned(iso.handle, val).?,
        };
    }

    pub fn getUint64(self: Self) u64 {
        return c.v8__BigInt__Uint64Value(self.handle, null);
    }

    pub fn getInt64(self: Self) i64 {
        return c.v8__BigInt__Int64Value(self.handle, null);
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
        PromiseResolver => val.handle,
        External => val.handle,
        Array => val.handle,
        Uint8Array => val.handle,
        StackTrace => val.handle,
        ObjectTemplate => val.handle,
        Persistent(Object) => val.inner.handle,
        Persistent(Value) => val.inner.handle,
        Persistent(String) => val.inner.handle,
        Persistent(Integer) => val.inner.handle,
        Persistent(Primitive) => val.inner.handle,
        Persistent(Number) => val.inner.handle,
        Persistent(PromiseResolver) => val.inner.handle,
        Persistent(Array) => val.inner.handle,
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
        Function => val.handle,
        Context => val.handle,
        Object => val.handle,
        Value => val.handle,
        Module => val.handle,
        Promise => val.handle,
        PromiseResolver => val.handle,
        else => @compileError(std.fmt.comptimePrint("{s} is not a subtype of v8::Data", .{@typeName(@TypeOf(val))})),
    });
}

pub const Message = struct {
    const Self = @This();

    handle: *const c.Message,

    pub fn getMessage(self: Self) String {
        return String{
            .handle = c.v8__Message__Get(self.handle).?,
        };
    }

    pub fn getSourceLine(self: Self, ctx: Context) ?String {
        if (c.v8__Message__GetSourceLine(self.handle, ctx.handle)) |string| {
            return String{
                .handle = string,
            };
        } else return null;
    }

    pub fn getScriptResourceName(self: Self) Value {
        return .{
            .handle = c.v8__Message__GetScriptResourceName(self.handle).?,
        };
    }

    pub fn getLineNumber(self: Self, ctx: Context) ?u32 {
        const res = c.v8__Message__GetLineNumber(self.handle, ctx.handle);
        if (res != -1) {
            return @intCast(u32, res);
        } else return null;
    }

    pub fn getStartColumn(self: Self) ?u32 {
        const res = c.v8__Message__GetStartColumn(self.handle);
        if (res != -1) {
            return @intCast(u32, res);
        } else return null;
    }

    pub fn getEndColumn(self: Self) ?u32 {
        const res = c.v8__Message__GetEndColumn(self.handle);
        if (res != -1) {
            return @intCast(u32, res);
        } else return null;
    }

    /// [v8] Exception stack trace. By default stack traces are not captured for
    ///      uncaught exceptions. SetCaptureStackTraceForUncaughtExceptions allows
    ///      to change this option.
    pub fn getStackTrace(self: Self) ?StackTrace {
        if (c.v8__Message__GetStackTrace(self.handle)) |trace| {
            return StackTrace{
                .handle = trace,
            };
        } else return null;
    }
};

pub const StackTrace = struct {
    const Self = @This();

    handle: *const c.StackTrace,

    pub fn getFrameCount(self: Self) u32 {
        return @intCast(u32, c.v8__StackTrace__GetFrameCount(self.handle));
    }

    pub fn getFrame(self: Self, iso: Isolate, idx: u32) StackFrame {
        return .{
            .handle = c.v8__StackTrace__GetFrame(self.handle, iso.handle, idx).?,
        };
    }

    pub fn getCurrentStackTrace(iso: Isolate, frame_limit: u32) StackTrace {
        return .{
            .handle = c.v8__StackTrace__CurrentStackTrace__STATIC(iso.handle, @intCast(c_int, frame_limit)).?,
        };
    }

    pub fn getCurrentScriptNameOrSourceUrl(iso: Isolate) String {
        return .{
            .handle = c.v8__StackTrace__CurrentScriptNameOrSourceURL__STATIC(iso.handle).?,
        };
    }
};

pub const StackFrame = struct {
    const Self = @This();

    handle: *const c.StackFrame,

    pub fn getLineNumber(self: Self) u32 {
        return @intCast(u32, c.v8__StackFrame__GetLineNumber(self.handle));
    }

    pub fn getColumn(self: Self) u32 {
        return @intCast(u32, c.v8__StackFrame__GetColumn(self.handle));
    }

    pub fn getScriptId(self: Self) u32 {
        return @intCast(u32, c.v8__StackFrame__GetScriptId(self.handle));
    }

    pub fn getScriptName(self: Self) String {
        return .{
            .handle = c.v8__StackFrame__GetScriptName(self.handle).?,
        };
    }

    pub fn getScriptNameOrSourceUrl(self: Self) String {
        return .{
            .handle = c.v8__StackFrame__GetScriptNameOrSourceURL(self.handle).?,
        };
    }

    pub fn getFunctionName(self: Self) ?String {
        if (c.v8__StackFrame__GetFunctionName(self.handle)) |ptr| {
            return String{
                .handle = ptr,
            };
        } else return null;
    }

    pub fn isEval(self: Self) bool {
        return c.v8__StackFrame__IsEval(self.handle);
    }

    pub fn isConstructor(self: Self) bool {
        return c.v8__StackFrame__IsConstructor(self.handle);
    }

    pub fn isWasm(self: Self) bool {
        return c.v8__StackFrame__IsWasm(self.handle);
    }

    pub fn isUserJavascript(self: Self) bool {
        return c.v8__StackFrame__IsUserJavaScript(self.handle);
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

    pub fn getException(self: Self) ?Value {
        if (c.v8__TryCatch__Exception(&self.inner)) |exception| {
            return Value{
                .handle = exception,
            };
        } else return null;
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
        } else return null;
    }

    pub fn isVerbose(self: Self) bool {
        return c.v8__TryCatch__IsVerbose(&self.inner);
    }

    pub fn setVerbose(self: *Self, verbose: bool) void {
        c.v8__TryCatch__SetVerbose(&self.inner, verbose);
    }

    pub fn rethrow(self: *Self) Value {
        return .{
            .handle = c.v8__TryCatch__ReThrow(&self.inner).?,
        };
    }
};

pub const ScriptOrigin = struct {
    const Self = @This();

    inner: c.ScriptOrigin,

    pub fn initDefault(isolate: Isolate, resource_name: Value) Self {
        var inner: c.ScriptOrigin = undefined;
        c.v8__ScriptOrigin__CONSTRUCT(&inner, isolate.handle, resource_name.handle);
        return .{
            .inner = inner,
        };
    }

    pub fn init(
        isolate: Isolate,
        resource_name: Value,
        resource_line_offset: i32,
        resource_column_offset: i32,
        resource_is_shared_cross_origin: bool,
        script_id: i32,
        source_map_url: ?Value,
        resource_is_opaque: bool,
        is_wasm: bool,
        is_module: bool,
        host_defined_options: ?Data,
    ) Self {
        var inner: c.ScriptOrigin = undefined;
        c.v8__ScriptOrigin__CONSTRUCT2(
            &inner,
            isolate.handle,
            resource_name.handle,
            resource_line_offset,
            resource_column_offset,
            resource_is_shared_cross_origin,
            script_id,
            if (source_map_url != null) source_map_url.?.handle else null,
            resource_is_opaque,
            is_wasm,
            is_module,
            if (host_defined_options != null) host_defined_options.?.handle else null,
        );
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

pub const ScriptCompilerSource = struct {
    const Self = @This();

    inner: c.ScriptCompilerSource,

    pub fn init(self: *Self, src: String, mb_origin: ?ScriptOrigin, cached_data: ?ScriptCompilerCachedData) void {
        const cached_data_ptr = if (cached_data != null) cached_data.?.handle else null;
        if (mb_origin) |origin| {
            c.v8__ScriptCompiler__Source__CONSTRUCT2(src.handle, &origin.inner, cached_data_ptr, &self.inner);
        } else {
            c.v8__ScriptCompiler__Source__CONSTRUCT(src.handle, cached_data_ptr, &self.inner);
        }
    }

    pub fn deinit(self: *Self) void {
        c.v8__ScriptCompiler__Source__DESTRUCT(&self.inner);
    }
};

pub const ScriptCompilerCachedData = struct {
    const Self = @This();

    handle: *c.ScriptCompilerCachedData,

    pub fn init(data: []const u8) Self {
        return .{
            .handle = c.v8__ScriptCompiler__CachedData__NEW(data.ptr, @intCast(c_int, data.len)).?,
        };
    }

    pub fn deinit(self: Self) void {
        c.v8__ScriptCompiler__CachedData__DELETE(self.handle);
    }
};

pub const ScriptCompiler = struct {

    const CompileOptions = enum(u32) {
        kNoCompileOptions = c.kNoCompileOptions,
        kConsumeCodeCache = c.kConsumeCodeCache,
        kEagerCompile = c.kEagerCompile,
    };

    const NoCacheReason = enum(u32) {
        kNoCacheNoReason = c.kNoCacheNoReason,
        kNoCacheBecauseCachingDisabled = c.kNoCacheBecauseCachingDisabled,
        kNoCacheBecauseNoResource = c.kNoCacheBecauseNoResource,
        kNoCacheBecauseInlineScript = c.kNoCacheBecauseInlineScript,
        kNoCacheBecauseModule = c.kNoCacheBecauseModule,
        kNoCacheBecauseStreamingSource = c.kNoCacheBecauseStreamingSource,
        kNoCacheBecauseInspector = c.kNoCacheBecauseInspector,
        kNoCacheBecauseScriptTooSmall = c.kNoCacheBecauseScriptTooSmall,
        kNoCacheBecauseCacheTooCold = c.kNoCacheBecauseCacheTooCold,
        kNoCacheBecauseV8Extension = c.kNoCacheBecauseV8Extension,
        kNoCacheBecauseExtensionModule = c.kNoCacheBecauseExtensionModule,
        kNoCacheBecausePacScript = c.kNoCacheBecausePacScript,
        kNoCacheBecauseInDocumentWrite = c.kNoCacheBecauseInDocumentWrite,
        kNoCacheBecauseResourceWithNoCacheHandler = c.kNoCacheBecauseResourceWithNoCacheHandler,
        kNoCacheBecauseDeferredProduceCodeCache = c.kNoCacheBecauseDeferredProduceCodeCache,
    };

    /// [v8]
    /// Compile an ES module, returning a Module that encapsulates the compiled code.
    /// Corresponds to the ParseModule abstract operation in the ECMAScript specification.
    pub fn compileModule(iso: Isolate, src: *ScriptCompilerSource, options: ScriptCompiler.CompileOptions, reason: ScriptCompiler.NoCacheReason) !Module {
        const mb_res = c.v8__ScriptCompiler__CompileModule(
            iso.handle, 
            &src.inner,
            @enumToInt(options),
            @enumToInt(reason),
        );
        if (mb_res) |res| {
            return Module{
                .handle = res,
            };
        } else return error.JsException;
    }
};

pub const Script = struct {
    const Self = @This();

    handle: *const c.Script,

    /// [v8]
    /// A shorthand for ScriptCompiler::Compile().
    pub fn compile(ctx: Context, src: String, origin: ?ScriptOrigin) !Self {
        if (c.v8__Script__Compile(ctx.handle, src.handle, if (origin != null) &origin.?.inner else null)) |handle| {
            return Self{
                .handle = handle,
            };
        } else return error.JsException;
    }

    pub fn run(self: Self, ctx: Context) !Value {
        if (c.v8__Script__Run(self.handle, ctx.handle)) |value| {
            return Value{
                .handle = value,
            };
        } else return error.JsException;
    }
};

pub const Module = struct {
    const Self = @This();

    const Status = enum(u32) {
        kUninstantiated = c.kUninstantiated,
        kInstantiating = c.kInstantiating,
        kInstantiated = c.kInstantiated,
        kEvaluating = c.kEvaluating,
        kEvaluated = c.kEvaluated,
        kErrored = c.kErrored,
    };

    handle: *const c.Module,

    pub fn getStatus(self: Self) Status {
        return @intToEnum(Status, c.v8__Module__GetStatus(self.handle));
    }

    pub fn getException(self: Self) Value {
        return .{
            .handle = c.v8__Module__GetException(self.handle).?,
        };
    }

    pub fn getModuleRequests(self: Self) FixedArray {
        return .{
            .handle = c.v8__Module__GetModuleRequests(self.handle).?,
        };
    }

    /// [v8]
    /// Instantiates the module and its dependencies.
    ///
    /// Returns an empty Maybe<bool> if an exception occurred during
    /// instantiation. (In the case where the callback throws an exception, that
    /// exception is propagated.)
    pub fn instantiate(self: Self, ctx: Context, cb: c.ResolveModuleCallback) !bool {
        var out: c.MaybeBool = undefined;
        c.v8__Module__InstantiateModule(self.handle, ctx.handle, cb, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return error.JsException;
    }

    /// Evaulates the module, assumes module has been instantiated.
    /// [v8]
    /// Evaluates the module and its dependencies.
    ///
    /// If status is kInstantiated, run the module's code and return a Promise
    /// object. On success, set status to kEvaluated and resolve the Promise with
    /// the completion value; on failure, set status to kErrored and reject the
    /// Promise with the error.
    ///
    /// If IsGraphAsync() is false, the returned Promise is settled.
    pub fn evaluate(self: Self, ctx: Context) !Value {
        if (c.v8__Module__Evaluate(self.handle, ctx.handle)) |res| {
            return Value{
                .handle = res,
            };
        } else return error.JsException;
    }

    pub fn getIdentityHash(self: Self) u32 {
        return @bitCast(u32, c.v8__Module__GetIdentityHash(self.handle));
    }

    pub fn getScriptId(self: Self) u32 {
        return @intCast(u32, c.v8__Module__ScriptId(self.handle));
    }
};

pub const ModuleRequest = struct {
    const Self = @This();

    handle: *const c.ModuleRequest,

    /// Returns the specifier of the import inside the double quotes
    pub fn getSpecifier(self: Self) String {
        return .{
            .handle = c.v8__ModuleRequest__GetSpecifier(self.handle).?,
        };
    }

    /// Returns the offset from the start of the source code.
    pub fn getSourceOffset(self: Self) u32 {
        return @intCast(u32, c.v8__ModuleRequest__GetSourceOffset(self.handle));
    }
};

pub const Data = struct {
    const Self = @This();

    handle: *const c.Data,

    /// Should only be called if you know the underlying type.
    pub fn castTo(self: Self, comptime T: type) T {
        switch (T) {
            ModuleRequest => {
                return .{
                    .handle = self.handle,
                };
            },
            else => unreachable,
        }
    }
};

pub const Value = struct {
    const Self = @This();

    handle: *const c.Value,

    pub fn toString(self: Self, ctx: Context) !String {
        return String{
            .handle = c.v8__Value__ToString(self.handle, ctx.handle) orelse return error.JsException,
        };
    }

    pub fn toDetailString(self: Self, ctx: Context) !String {
        return String{
            .handle = c.v8__Value__ToDetailString(self.handle, ctx.handle) orelse return error.JsException,
        };
    }

    pub fn toBool(self: Self, isolate: Isolate) bool {
        return c.v8__Value__BooleanValue(self.handle, isolate.handle);
    }

    pub fn toI32(self: Self, ctx: Context) !i32 {
        var out: c.MaybeI32 = undefined;
        c.v8__Value__Int32Value(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return out.value;
        } else return error.JsException;
    }

    pub fn toU32(self: Self, ctx: Context) !u32 {
        var out: c.MaybeU32 = undefined;
        c.v8__Value__Uint32Value(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return out.value;
        } else return error.JsException;
    }

    pub fn toF32(self: Self, ctx: Context) !f32 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return @floatCast(f32, out.value);
        } else return error.JsException;
    }

    pub fn toF64(self: Self, ctx: Context) !f64 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return out.value;
        } else return error.JsException;
    }

    pub fn bitCastToU64(self: Self, ctx: Context) !u64 {
        var out: c.MaybeF64 = undefined;
        c.v8__Value__NumberValue(self.handle, ctx.handle, &out);
        if (out.has_value == 1) {
            return @bitCast(u64, out.value);
        } else return error.JsException;
    }

    pub fn instanceOf(self: Self, ctx: Context, obj: Object) !bool {
        var out: c.MaybeBool = undefined;
        c.v8__Value__InstanceOf(self.handle, ctx.handle, obj.handle, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return error.JsException;
    }

    pub fn isObject(self: Self) bool {
        return c.v8__Value__IsObject(self.handle);
    }

    pub fn isString(self: Self) bool {
        return c.v8__Value__IsString(self.handle);
    }

    pub fn isFunction(self: Self) bool {
        return c.v8__Value__IsFunction(self.handle);
    }

    pub fn isAsyncFunction(self: Self) bool {
        return c.v8__Value__IsAsyncFunction(self.handle);
    }

    pub fn isArray(self: Self) bool {
        return c.v8__Value__IsArray(self.handle);
    }

    pub fn isArrayBuffer(self: Self) bool {
        return c.v8__Value__IsArrayBuffer(self.handle);
    }

    pub fn isArrayBufferView(self: Self) bool {
        return c.v8__Value__IsArrayBufferView(self.handle);
    }

    pub fn isUint8Array(self: Self) bool {
        return c.v8__Value__IsUint8Array(self.handle);
    }

    pub fn isExternal(self: Self) bool {
        return c.v8__Value__IsExternal(self.handle);
    }

    pub fn isTrue(self: Self) bool {
        return c.v8__Value__IsTrue(self.handle);
    }

    pub fn isFalse(self: Self) bool {
        return c.v8__Value__IsFalse(self.handle);
    }

    pub fn isUndefined(self: Self) bool {
        return c.v8__Value__IsUndefined(self.handle);
    }

    pub fn isNull(self: Self) bool {
        return c.v8__Value__IsNull(self.handle);
    }

    pub fn isNullOrUndefined(self: Self) bool {
        return c.v8__Value__IsNullOrUndefined(self.handle);
    }

    pub fn isNativeError(self: Self) bool {
        return c.v8__Value__IsNativeError(self.handle);
    }

    pub fn isBigInt(self: Self) bool {
        return c.v8__Value__IsBigInt(self.handle);
    }

    pub fn isBigIntObject(self: Self) bool {
        return c.v8__Value__IsBigIntObject(self.handle);
    }

    /// Should only be called if you know the underlying type.
    pub fn castTo(self: Self, comptime T: type) T {
        switch (T) {
            Object,
            Function,
            Array,
            Promise,
            External,
            Integer,
            ArrayBuffer,
            ArrayBufferView,
            Uint8Array,
            String => {
                return .{
                    .handle = self.handle,
                };
            },
            else => unreachable,
        }
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

pub fn initNull(isolate: Isolate) Primitive {
    return .{
        .handle = c.v8__Null(isolate.handle).?,
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

pub const Promise = struct {
    const Self = @This();

    pub const State = enum(u32) {
        kPending = c.kPending,
        kFulfilled = c.kFulfilled,
        kRejected = c.kRejected,
    };

    handle: *const c.Promise,

    /// [V8]
    /// Register a resolution/rejection handler with a promise.
    /// The handler is given the respective resolution/rejection value as
    /// an argument. If the promise is already resolved/rejected, the handler is
    /// invoked at the end of turn.
    pub fn onCatch(self: Self, ctx: Context, handler: Function) !Promise {
        if (c.v8__Promise__Catch(self.handle, ctx.handle, handler.handle)) |handle| {
            return Promise{ .handle = handle };
        } else return error.JsException;
    }

    pub fn then(self: Self, ctx: Context, handler: Function) !Promise {
        if (c.v8__Promise__Then(self.handle, ctx.handle, handler.handle)) |handle| {
            return Promise{ .handle = handle };
        } else return error.JsException;
    }

    pub fn thenAndCatch(self: Self, ctx: Context, on_fulfilled: Function, on_rejected: Function) !Promise {
        if (c.v8__Promise__Then2(self.handle, ctx.handle, on_fulfilled.handle, on_rejected.handle)) |handle| {
            return Promise{ .handle = handle };
        } else return error.JsException;
    }

    pub fn getState(self: Self) State {
        return @intToEnum(State, c.v8__Promise__State(self.handle));
    }

    /// [V8]
    /// Marks this promise as handled to avoid reporting unhandled rejections.
    pub fn markAsHandled(self: Self) void {
        c.v8__Promise__MarkAsHandled(self.handle);
    }

    pub fn toObject(self: Self) Object {
        return .{
            .handle = @ptrCast(*const c.Object, self.handle),
        };
    }

    /// [V8]
    /// Returns the content of the [[PromiseResult]] field. The Promise must not be pending.
    pub fn getResult(self: Self) Value {
        return .{
            .handle = c.v8__Promise__Result(self.handle).?,
        };
    }
};

pub const PromiseResolver = struct {
    const Self = @This();

    handle: *const c.PromiseResolver,

    pub fn init(ctx: Context) Self {
        return .{
            .handle = c.v8__Promise__Resolver__New(ctx.handle).?,
        };
    }

    pub fn getPromise(self: Self) Promise {
        return .{
            .handle = c.v8__Promise__Resolver__GetPromise(self.handle).?,
        };
    }

    /// Resolve will continue execution of any yielding generators.
    pub fn resolve(self: Self, ctx: Context, val: Value) ?bool {
        var out: c.MaybeBool = undefined;
        c.v8__Promise__Resolver__Resolve(self.handle, ctx.handle, val.handle, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return null;
    }

    /// Reject will continue execution of any yielding generators.
    pub fn reject(self: Self, ctx: Context, val: Value) ?bool {
        var out: c.MaybeBool = undefined;
        c.v8__Promise__Resolver__Reject(self.handle, ctx.handle, val.handle, &out);
        if (out.has_value == 1) {
            return out.value == 1;
        } else return null;
    }
};

pub const BackingStore = struct {
    const Self = @This();

    handle: *c.BackingStore,

    /// Underlying handle is initially unmanaged.
    pub fn init(iso: Isolate, len: usize) Self {
        return .{
            .handle = c.v8__ArrayBuffer__NewBackingStore(iso.handle, len).?,
        };
    }

    /// Returns null if len is 0.
    pub fn getData(self: Self) ?*anyopaque {
        return c.v8__BackingStore__Data(self.handle);
    }

    pub fn getByteLength(self: Self) usize {
        return c.v8__BackingStore__ByteLength(self.handle);
    }

    pub fn isShared(self: Self) bool {
        return c.v8__BackingStore__IsShared(self.handle);
    }

    pub fn toSharedPtr(self: Self) SharedPtr {
        return c.v8__BackingStore__TO_SHARED_PTR(self.handle);
    }

    pub fn sharedPtrReset(ptr: *SharedPtr) void {
        c.std__shared_ptr__v8__BackingStore__reset(ptr);
    }

    pub fn sharedPtrGet(ptr: *const SharedPtr) Self {
        return .{
            .handle = c.std__shared_ptr__v8__BackingStore__get(ptr).?,
        };
    }

    pub fn sharedPtrUseCount(ptr: *const SharedPtr) u32 {
        return @intCast(u32, c.std__shared_ptr__v8__BackingStore__use_count(ptr));
    }
};

pub const ArrayBuffer = struct {
    const Self = @This();

    handle: *const c.ArrayBuffer,

    pub fn init(iso: Isolate, len: usize) Self {
        return .{
            .handle = c.v8__ArrayBuffer__New(iso.handle, len).?,
        };
    }

    pub fn initWithBackingStore(iso: Isolate, store: *const SharedPtr) Self {
        return .{
            .handle = c.v8__ArrayBuffer__New2(iso.handle, store).?,
        };
    }

    pub fn getBackingStore(self: Self) SharedPtr {
        return c.v8__ArrayBuffer__GetBackingStore(self.handle);
    }
};

pub const ArrayBufferView = struct {
    const Self = @This();

    handle: *const c.ArrayBufferView,

    pub fn getBuffer(self: Self) ArrayBuffer {
        return .{
            .handle = c.v8__ArrayBufferView__Buffer(self.handle).?,
        };
    }

    pub fn castFrom(val: anytype) Self {
        switch (@TypeOf(val)) {
            Uint8Array => return .{
                .handle = @ptrCast(*const c.ArrayBufferView, val.handle),
            },
            else => unreachable,
        }
    }
};

pub const FixedArray = struct {
    const Self = @This();

    handle: *const c.FixedArray,

    pub fn length(self: Self) u32 {
        return @intCast(u32, c.v8__FixedArray__Length(self.handle));
    }

    pub fn get(self: Self, ctx: Context, idx: u32) Data {
        return .{
            .handle = c.v8__FixedArray__Get(self.handle, ctx.handle, @intCast(c_int, idx)).?,
        };
    }
};

pub const Uint8Array = struct {
    const Self = @This();

    handle: *const c.Uint8Array,

    pub fn init(buf: ArrayBuffer, offset: usize, len: usize) Self {
        return .{
            .handle = c.v8__Uint8Array__New(buf.handle, offset, len).?,
        };
    }
};

pub const Json = struct {

    pub fn parse(ctx: Context, json: String) !Value {
        return Value{
            .handle = c.v8__JSON__Parse(ctx.handle, json.handle) orelse return error.JsException,
        };
    }

    pub fn stringify(ctx: Context, val: Value, gap: ?String) !String {
        return String{
            .handle = c.v8__JSON__Stringify(ctx.handle, val.handle, if (gap != null) gap.?.handle else null) orelse return error.JsException,
        };
    }
};

inline fn ptrCastAlign(comptime Ptr: type, ptr: anytype) Ptr {
    const alignment = @typeInfo(Ptr).Pointer.alignment;
    if (alignment == 0) {
        return @ptrCast(Ptr, ptr);
    } else {
        return @ptrCast(Ptr, @alignCast(alignment, ptr));
    }
}

pub fn setDcheckFunction(func: fn (file: [*c]const u8, line: c_int, msg: [*c]const u8) callconv(.C) void) void {
    c.v8__base__SetDcheckFunction(func);
}