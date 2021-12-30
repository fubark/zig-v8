#include <stdint.h>

typedef char bool;
typedef uintptr_t usize;
typedef struct CreateParams CreateParams;
typedef struct Isolate Isolate;
typedef struct String String;
typedef struct Boolean Boolean;
typedef struct Function Function;
typedef struct FunctionTemplate FunctionTemplate;
typedef struct Object Object;
typedef struct Name Name;
typedef struct Context Context;
// Super type.
typedef void Value;
typedef struct SharedPtr {
    usize a;
    usize b;
} SharedPtr;
typedef uintptr_t IntAddress; // v8::internal::Address

typedef struct MaybeU32 {
    bool has_value;
    uint32_t value;
} MaybeU32;
typedef struct MaybeF64 {
    bool has_value;
    double value;
} MaybeF64;
typedef struct MaybeBool {
    bool has_value;
    bool value;
} MaybeBool;
typedef enum PropertyAttribute {
    /** None. **/
    None = 0,
    /** ReadOnly, i.e., not writable. **/
    ReadOnly = 1 << 0,
    /** DontEnum, i.e., not enumerable. **/
    DontEnum = 1 << 1,
    /** DontDelete, i.e., not configurable. **/
    DontDelete = 1 << 2
} PropertyAttribute;

// Platform
typedef struct Platform Platform;
Platform* v8__Platform__NewDefaultPlatform(int thread_pool_size, int idle_task_support);
void v8__Platform__DELETE(Platform* platform);
bool v8__Platform__PumpMessageLoop(Platform* platform, Isolate* isolate, bool wait_for_work);

// Root
typedef struct Primitive Primitive;
const Primitive* v8__Undefined(
    Isolate* isolate);
const Boolean* v8__True(
    Isolate* isolate);
const Boolean* v8__False(
    Isolate* isolate);

// V8
void v8__V8__InitializePlatform(Platform* platform);
void v8__V8__Initialize();
int v8__V8__Dispose();
void v8__V8__ShutdownPlatform();
const char* v8__V8__GetVersion();

// Isolate
Isolate* v8__Isolate__New(CreateParams* params);
void v8__Isolate__Enter(Isolate* isolate);
void v8__Isolate__Exit(Isolate* isolate);
void v8__Isolate__Dispose(Isolate* isolate);
Context* v8__Isolate__GetCurrentContext(Isolate* isolate);
const Value* v8__Isolate__ThrowException(
    Isolate* isolate,
    const Value* exception);

typedef struct StartupData StartupData;

typedef struct ArrayBufferAllocator ArrayBufferAllocator;
ArrayBufferAllocator* v8__ArrayBuffer__Allocator__NewDefaultAllocator();
void v8__ArrayBuffer__Allocator__DELETE(ArrayBufferAllocator* self);

typedef struct ResourceConstraints {
    usize code_range_size_;
    usize max_old_generation_size_;
    usize max_young_generation_size_;
    usize initial_old_generation_size_;
    usize initial_young_generation_size_;
    uint32_t* stack_limit_;
} ResourceConstraints;

typedef struct CreateParams {
    void* code_event_handler; // JitCodeEventHandler
    ResourceConstraints constraints;
    StartupData* snapshot_blob;
    void* counter_lookup_callback;
    void* create_histogram_callback; // CreateHistogramCallback
    void* add_histogram_sample_callback; // AddHistogramSampleCallback
    ArrayBufferAllocator* array_buffer_allocator;
    SharedPtr array_buffer_allocator_shared;
    const intptr_t* external_references;
    bool allow_atomics_wait;
    bool only_terminate_in_safe_scope;
    int embedder_wrapper_type_index;
    int embedder_wrapper_object_index;
    Isolate* experimental_attach_to_shared_isolate;
} CreateParams;
usize v8__Isolate__CreateParams__SIZEOF();
void v8__Isolate__CreateParams__CONSTRUCT(CreateParams* buf);

typedef struct StartupData {
    const char* data;
    int raw_size;
} StartupData;

// HandleScope
typedef struct Address Address;
typedef struct HandleScope {
    // internal vars.
    Isolate* isolate_;
    Address* prev_next_;
    Address* prev_limit_;
} HandleScope;
void v8__HandleScope__CONSTRUCT(HandleScope* buf, Isolate* isolate);
void v8__HandleScope__DESTRUCT(HandleScope* scope);

// Message
typedef struct Message Message;
const String* v8__Message__GetSourceLine(const Message* self, const Context* context);
const Value* v8__Message__GetScriptResourceName(const Message* self);
int v8__Message__GetLineNumber(const Message* self, const Context* context);
int v8__Message__GetStartColumn(const Message* self);
int v8__Message__GetEndColumn(const Message* self);

// TryCatch
typedef struct TryCatch {
    void* isolate_;
    struct TryCatch* next_;
    void* exception_;
    void* message_obj_;
    IntAddress js_stack_comparable_address_;
    usize flags;
} TryCatch;
usize v8__TryCatch__SIZEOF();
void v8__TryCatch__CONSTRUCT(TryCatch* buf, Isolate* isolate);
void v8__TryCatch__DESTRUCT(TryCatch* self);
const Value* v8__TryCatch__Exception(const TryCatch* self);
const Message* v8__TryCatch__Message(const TryCatch* self);
bool v8__TryCatch__HasCaught(const TryCatch* self);
const Value* v8__TryCatch__StackTrace(const TryCatch* self, const Context* context);

// Context
typedef struct Context Context;
typedef struct ObjectTemplate ObjectTemplate;
Context* v8__Context__New(Isolate* isolate, const ObjectTemplate* global_tmpl, const Value* global_obj);
void v8__Context__Enter(const Context* context);
void v8__Context__Exit(const Context* context);
Isolate* v8__Context__GetIsolate(const Context* context);
const Object* v8__Context__Global(const Context* self);

// Boolean
const Boolean* v8__Boolean__New(
    Isolate* isolate,
    bool value);

// String
typedef enum NewStringType {
    /**
     * Create a new string, always allocating new storage memory.
     */
    kNormal,

    /**
     * Acts as a hint that the string should be created in the
     * old generation heap space and be deduplicated if an identical string
     * already exists.
     */
    kInternalized
} NewStringType;
typedef enum WriteOptions {
    NO_OPTIONS = 0,
    HINT_MANY_WRITES_EXPECTED = 1,
    NO_NULL_TERMINATION = 2,
    PRESERVE_ONE_BYTE_NULL = 4,
    // Used by WriteUtf8 to replace orphan surrogate code units with the
    // unicode replacement character. Needs to be set to guarantee valid UTF-8
    // output.
    REPLACE_INVALID_UTF8 = 8
} WriteOptions;
String* v8__String__NewFromUtf8(Isolate* isolate, const char* data, NewStringType type, int length);
int v8__String__WriteUtf8(const String* str, Isolate* isolate, const char* buf, int len, int* nchars, WriteOptions options);
int v8__String__Utf8Length(const String* str, Isolate* isolate);

// Value
String* v8__Value__ToString(const Value* val, const Context* ctx);
bool v8__Value__BooleanValue(
    const Value* self,
    Isolate* isolate);
void v8__Value__Uint32Value(
    const Value* self,
    const Context* ctx,
    MaybeU32* out);
void v8__Value__NumberValue(
    const Value* self,
    const Context* context,
    MaybeF64* out);
bool v8__Value__IsFunction(const Value* self);
bool v8__Value__IsAsyncFunction(const Value* self);
bool v8__Value__IsObject(const Value* self);
bool v8__Value__IsArray(const Value* self);
void v8__Value__InstanceOf(
    const Value* self,
    const Context* ctx,
    const Object* object,
    MaybeBool* out);

// Promise
typedef struct Promise Promise;
typedef struct PromiseResolver PromiseResolver;
const PromiseResolver* v8__Promise__Resolver__New(
    const Context* ctx);
const Promise* v8__Promise__Resolver__GetPromise(
    const PromiseResolver* self);
void v8__Promise__Resolver__Resolve(
    const PromiseResolver* self,
    const Context* ctx,
    const Value* value,
    MaybeBool* out);
void v8__Promise__Resolver__Reject(
    const PromiseResolver* self,
    const Context* ctx,
    const Value* value,
    MaybeBool* out);
const Promise* v8__Promise__Catch(
    const Promise* self,
    const Context* ctx,
    const Function* handler);
const Promise* v8__Promise__Then(
    const Promise* self,
    const Context* ctx,
    const Function* handler);
const Promise* v8__Promise__Then2(
    const Promise* self,
    const Context* ctx,
    const Function* on_fulfilled,
    const Function* on_rejected);

// Array
typedef struct Array Array;
uint32_t v8__Array__Length(const Array* self);

// Object
const Object* v8__Object__New(
    Isolate* isolate);
const Value* v8__Object__GetInternalField(
    const Object* self,
    int index);
void v8__Object__SetInternalField(
    const Object* self,
    int index,
    const Value* value);
const Value* v8__Object__Get(
    const Object* self,
    const Context* ctx,
    const Value* key);
const Value* v8__Object__GetIndex(
    const Object* self,
    const Context* ctx,
    uint32_t idx);
void v8__Object__Set(
    const Object* self,
    const Context* ctx,
    const Value* key,
    const Value* value,
    MaybeBool* out);
void v8__Object__DefineOwnProperty(
    const Object* self,
    const Context* ctx,
    const Name* key,
    const Value* value,
    PropertyAttribute attr,
    MaybeBool* out);

// Exception
const Value* v8__Exception__Error(
    const String* message);

// Number
typedef struct Number Number;
const Number* v8__Number__New(
    Isolate* isolate,
    double value);

// Integer
typedef struct Integer Integer;
const Integer* v8__Integer__New(
    Isolate* isolate,
    int32_t value);
const Integer* v8__Integer__NewFromUnsigned(
    Isolate* isolate,
    uint32_t value);

// Template
typedef struct Template Template;
typedef struct Data Data;
void v8__Template__Set(
    const Template* self,
    const Name* key,
    const Data* value,
    PropertyAttribute attr);
void v8__Template__SetAccessorProperty__DEFAULT(
    const Template* self,
    const Name* key,
    const FunctionTemplate* getter);

// FunctionCallbackInfo
typedef struct FunctionCallbackInfo FunctionCallbackInfo;
typedef struct ReturnValue {
    uintptr_t addr;
} ReturnValue;
Isolate* v8__FunctionCallbackInfo__GetIsolate(
    const FunctionCallbackInfo* self);
int v8__FunctionCallbackInfo__Length(
    const FunctionCallbackInfo* self);
const Value* v8__FunctionCallbackInfo__INDEX(
    const FunctionCallbackInfo* self, int i);
void v8__FunctionCallbackInfo__GetReturnValue(
    const FunctionCallbackInfo* self,
    ReturnValue* res);
const Object* v8__FunctionCallbackInfo__This(
    const FunctionCallbackInfo* self);
const Value* v8__FunctionCallbackInfo__Data(
    const FunctionCallbackInfo* self);

// PropertyCallbackInfo
typedef struct PropertyCallbackInfo PropertyCallbackInfo;
Isolate* v8__PropertyCallbackInfo__GetIsolate(
    const PropertyCallbackInfo* self);
void v8__PropertyCallbackInfo__GetReturnValue(
    const PropertyCallbackInfo* self,
    ReturnValue* res);
const Object* v8__PropertyCallbackInfo__This(
    const PropertyCallbackInfo* self);
const Value* v8__PropertyCallbackInfo__Data(
    const PropertyCallbackInfo* self);

// ReturnValue
void v8__ReturnValue__Set(
    const ReturnValue self,
    const Value* value);
const Value* v8__ReturnValue__Get(
    const ReturnValue self);

// FunctionTemplate
typedef void (*FunctionCallback)(const FunctionCallbackInfo*);
const FunctionTemplate* v8__FunctionTemplate__New__DEFAULT(
    Isolate* isolate);
const FunctionTemplate* v8__FunctionTemplate__New__DEFAULT2(
    Isolate* isolate,
    FunctionCallback callback_or_null);
const FunctionTemplate* v8__FunctionTemplate__New__DEFAULT3(
    Isolate* isolate,
    FunctionCallback callback_or_null,
    const Value* data);
const ObjectTemplate* v8__FunctionTemplate__InstanceTemplate(
    const FunctionTemplate* self);
const ObjectTemplate* v8__FunctionTemplate__PrototypeTemplate(
    const FunctionTemplate* self);
const Function* v8__FunctionTemplate__GetFunction(
    const FunctionTemplate* self, const Context* context);
void v8__FunctionTemplate__SetClassName(
    const FunctionTemplate* self,
    const String* name);
void v8__FunctionTemplate__ReadOnlyPrototype(
    const FunctionTemplate* self);

// Function
const Function* v8__Function__New__DEFAULT(
    const Context* ctx,
    FunctionCallback callback);
const Function* v8__Function__New__DEFAULT2(
    const Context* ctx,
    FunctionCallback callback,
    const Value* data);
const Value* v8__Function__Call(
    const Function* self,
    const Context* context,
    const Value* recv,
    int argc,
    const Value* const argv[]);
const Object* v8__Function__NewInstance(
    const Function* self,
    const Context* context,
    int argc,
    const Value* const argv[]);

// External
typedef struct External External;
const External* v8__External__New(
    Isolate* isolate, 
    void* value);
void* v8__External__Value(
    const External* self);

// Persistent
typedef struct Persistent {
    uintptr_t val_ptr;
} Persistent;
void v8__Persistent__New(
    Isolate* isolate,
    const Value* value,
    Persistent* out);
void v8__Persistent__Reset(
    Persistent* self);
void v8__Persistent__SetWeak(
    Persistent* self);
typedef struct WeakCallbackInfo WeakCallbackInfo;
typedef void (*WeakCallback)(const WeakCallbackInfo*);
typedef enum WeakCallbackType {
    kParameter,
    kInternalFields,
    kFinalizer
} WeakCallbackType;
void v8__Persistent__SetWeakFinalizer(
    Persistent* self,
    void* finalizer_ctx,
    WeakCallback finalizer_cb,
    WeakCallbackType type);

// WeakCallbackInfo
Isolate* v8__WeakCallbackInfo__GetIsolate(
    const WeakCallbackInfo* self);
void* v8__WeakCallbackInfo__GetParameter(
    const WeakCallbackInfo* self);

// ObjectTemplate
typedef struct Object Object;
typedef struct ObjectTemplate ObjectTemplate;
ObjectTemplate* v8__ObjectTemplate__New__DEFAULT(
    Isolate* isolate);
ObjectTemplate* v8__ObjectTemplate__New(
    Isolate* isolate, const FunctionTemplate* templ);
Object* v8__ObjectTemplate__NewInstance(
    const ObjectTemplate* self, const Context* ctx);
void v8__ObjectTemplate__SetInternalFieldCount(
    const ObjectTemplate* self,
    int value);
typedef void (*AccessorNameGetterCallback)(const Name*, const PropertyCallbackInfo*);
typedef void (*AccessorNameSetterCallback)(const Name*, const Value*, const PropertyCallbackInfo*);
void v8__ObjectTemplate__SetAccessor__DEFAULT(
    const ObjectTemplate* self,
    const Name* key,
    AccessorNameGetterCallback getter);
void v8__ObjectTemplate__SetAccessor__DEFAULT2(
    const ObjectTemplate* self,
    const Name* key,
    AccessorNameGetterCallback getter,
    AccessorNameSetterCallback setter);

// ScriptOrigin
typedef struct ScriptOriginOptions {
    const int flags_;
} ScriptOriginOptions;
typedef struct ScriptOrigin {
    Isolate* isolate_;
    Value* resource_name_;
    int resource_line_offset_;
    int resource_column_offset_;
    ScriptOriginOptions options_;
    int script_id_;
    Value* source_map_url_;
    void* host_defined_options_;
} ScriptOrigin;
void v8__ScriptOrigin__CONSTRUCT(ScriptOrigin* buf, Isolate* isolate, const Value* resource_name);

// Script
typedef struct Script Script;
Script* v8__Script__Compile(const Context* context, const String* src, const ScriptOrigin* origin);
Value* v8__Script__Run(const Script* script, const Context* context);
