#include <stdint.h>

typedef char bool;
typedef uintptr_t usize;
typedef struct CreateParams CreateParams;
typedef struct Isolate Isolate;
typedef struct String String;
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

// Platform
typedef struct Platform Platform;
Platform* v8__Platform__NewDefaultPlatform(int thread_pool_size, int idle_task_support);
void v8__Platform__DELETE(Platform* platform);
bool v8__Platform__PumpMessageLoop(Platform* platform, Isolate* isolate, bool wait_for_work);

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
Context* v8__Context__New(Isolate* isolate, ObjectTemplate* global_tmpl, Value* global_obj);
void v8__Context__Enter(Context* context);
void v8__Context__Exit(Context* context);
Isolate* v8__Context__GetIsolate(const Context* context);

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
void v8__Value__Uint32Value(
    const Value* self,
    const Context* ctx,
    const MaybeU32* out);

// Template
typedef struct Template Template;
typedef struct Name Name;
typedef struct Data Data;
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
void v8__Template__Set(
    const Template* self,
    const Name* key,
    const Data* value,
    PropertyAttribute attr);

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

// ReturnValue
void v8__ReturnValue__Set(
    const ReturnValue self,
    const Value* value);
const Value* v8__ReturnValue__Get(
    const ReturnValue self);

// FunctionTemplate
typedef struct FunctionTemplate FunctionTemplate;
typedef void (*FunctionCallback)(const FunctionCallbackInfo*);
const FunctionTemplate* v8__FunctionTemplate__New__DEFAULT(
    Isolate* isolate,
    FunctionCallback callback_or_null);

// ObjectTemplate
typedef struct Object Object;
typedef struct ObjectTemplate ObjectTemplate;
ObjectTemplate* v8__ObjectTemplate__New__DEFAULT(
    Isolate* isolate);
ObjectTemplate* v8__ObjectTemplate__New(
    Isolate* isolate, const FunctionTemplate* templ);
Object* v8__ObjectTemplate__NewInstance(
    const ObjectTemplate* self, const Context* ctx);

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
