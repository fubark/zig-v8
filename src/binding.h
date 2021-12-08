#include <stdint.h>

typedef char bool;
typedef uintptr_t usize;
typedef struct CreateParams CreateParams;
typedef struct Value Value;
typedef struct SharedPtr {
    usize a;
    usize b;
} SharedPtr;

// V8
void v8__V8__Initialize();
int v8__V8__Dispose();
void v8__V8__ShutdownPlatform();

// Platform
typedef struct Platform Platform;
Platform* v8__Platform__NewDefaultPlatform(int thread_pool_size, int idle_task_support);
void v8__V8__InitializePlatform(Platform* platform);
void v8__Platform__DELETE(Platform* platform);

// Isolate
typedef struct Isolate Isolate;
Isolate* v8__Isolate__New(CreateParams* params);
void v8__Isolate__Enter(Isolate* isolate);
void v8__Isolate__Exit(Isolate* isolate);
void v8__Isolate__Dispose(Isolate* isolate);

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

// Context
typedef struct Context Context;
typedef struct ObjectTemplate ObjectTemplate;
Context* v8__Context__New(Isolate* isolate, ObjectTemplate* global_tmpl, Value* global_obj);
void v8__Context__Enter(Context* context);
void v8__Context__Exit(Context* context);

// String
typedef struct String String;
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

// Script
typedef struct Script Script;
typedef struct ScriptOrigin ScriptOrigin;
Script* v8__Script__Compile(const Context* context, const String* src, const ScriptOrigin* origin);
Value* v8__Script__Run(const Script* script, const Context* context);