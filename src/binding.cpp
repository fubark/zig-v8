// Based on https://github.com/denoland/rusty_v8/blob/main/src/binding.cc

#include <cassert>
#include "include/libplatform/libplatform.h"
#include "include/v8.h"

template <class T, class... Args>
class Wrapper {
    public:
        Wrapper(T* buf, Args... args) : inner_(args...) {}
    private:
        T inner_;
};

template <class T, class... Args>
void construct_in_place(T* buf, Args... args) {
    new (buf) Wrapper<T, Args...>(buf, std::forward<Args>(args)...);
}

template <class T>
inline static T* local_to_ptr(v8::Local<T> local) {
    return *local;
}

template <class T>
inline static const v8::Local<T> ptr_to_local(const T* ptr) {
    static_assert(sizeof(v8::Local<T>) == sizeof(T*), "");
    auto local = *reinterpret_cast<const v8::Local<T>*>(&ptr);
    assert(*local == ptr);
    return local;
}

template <class T>
inline static const v8::MaybeLocal<T> ptr_to_maybe_local(const T* ptr) {
    static_assert(sizeof(v8::MaybeLocal<T>) == sizeof(T*), "");
    return *reinterpret_cast<const v8::MaybeLocal<T>*>(&ptr);
}

template <class T>
inline static T* maybe_local_to_ptr(v8::MaybeLocal<T> local) {
    return *local.FromMaybe(v8::Local<T>());
}

template <class T>
inline static v8::Local<T>* const_ptr_array_to_local_array(
        const T* const ptr_array[]) {
    static_assert(sizeof(v8::Local<T>) == sizeof(T*), "");
    auto mut_ptr_array = const_cast<T**>(ptr_array);
    auto mut_local_array = reinterpret_cast<v8::Local<T>*>(mut_ptr_array);
    return mut_local_array;
}

extern "C" {

// Platform

v8::Platform* v8__Platform__NewDefaultPlatform(
        int thread_pool_size,
        bool idle_task_support) {
    return v8::platform::NewDefaultPlatform(
        thread_pool_size,  
        idle_task_support ? v8::platform::IdleTaskSupport::kEnabled : v8::platform::IdleTaskSupport::kDisabled,
        v8::platform::InProcessStackDumping::kDisabled,
        nullptr
    ).release();
}

void v8__Platform__DELETE(v8::Platform* self) { delete self; }

bool v8__Platform__PumpMessageLoop(
        v8::Platform* platform,
        v8::Isolate* isolate,
        bool wait_for_work) {
    return v8::platform::PumpMessageLoop(
        platform, isolate,
        wait_for_work ? v8::platform::MessageLoopBehavior::kWaitForWork : v8::platform::MessageLoopBehavior::kDoNotWait);
}

// Root

const v8::Primitive* v8__Undefined(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::Undefined(isolate));
}

const v8::Boolean* v8__True(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::True(isolate));
}

const v8::Boolean* v8__False(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::False(isolate));
}

// V8

const char* v8__V8__GetVersion() { return v8::V8::GetVersion(); }

void v8__V8__InitializePlatform(v8::Platform* platform) {
    v8::V8::InitializePlatform(platform);
}

void v8__V8__Initialize() { v8::V8::Initialize(); }

int v8__V8__Dispose() { return v8::V8::Dispose(); }

void v8__V8__ShutdownPlatform() { v8::V8::ShutdownPlatform(); }

// ArrayBuffer

v8::ArrayBuffer::Allocator* v8__ArrayBuffer__Allocator__NewDefaultAllocator() {
    return v8::ArrayBuffer::Allocator::NewDefaultAllocator();
}

void v8__ArrayBuffer__Allocator__DELETE(v8::ArrayBuffer::Allocator* self) { delete self; }

// Isolate

v8::Isolate* v8__Isolate__New(const v8::Isolate::CreateParams& params) {
    return v8::Isolate::New(params);
}

void v8__Isolate__Dispose(v8::Isolate* isolate) { isolate->Dispose(); }

void v8__Isolate__Enter(v8::Isolate* isolate) { isolate->Enter(); }

void v8__Isolate__Exit(v8::Isolate* isolate) { isolate->Exit(); }

const v8::Context* v8__Isolate__GetCurrentContext(v8::Isolate* isolate) {
    return local_to_ptr(isolate->GetCurrentContext());
}

size_t v8__Isolate__CreateParams__SIZEOF() {
    return sizeof(v8::Isolate::CreateParams);
}

void v8__Isolate__CreateParams__CONSTRUCT(v8::Isolate::CreateParams* buf) {
    // Use in place new constructor otherwise special fields like shared_ptr will attempt to do copy and fail if the buffer had undefined values.
    new (buf) v8::Isolate::CreateParams();
}

const v8::Value* v8__Isolate__ThrowException(
        v8::Isolate* isolate,
        const v8::Value& exception) {
    return local_to_ptr(isolate->ThrowException(ptr_to_local(&exception)));
}

// HandleScope

void v8__HandleScope__CONSTRUCT(v8::HandleScope* buf, v8::Isolate* isolate) {
    // We can't do in place new, since new is overloaded for HandleScope.
    // Use in place construct instead.
    construct_in_place<v8::HandleScope>(buf, isolate);
}

void v8__HandleScope__DESTRUCT(v8::HandleScope* scope) { scope->~HandleScope(); }

// Context

v8::Context* v8__Context__New(
        v8::Isolate* isolate,
        const v8::ObjectTemplate* global_tmpl,
        const v8::Value* global_obj) {
    return local_to_ptr(
        v8::Context::New(isolate, nullptr, ptr_to_maybe_local(global_tmpl), ptr_to_maybe_local(global_obj))
    );
}

void v8__Context__Enter(const v8::Context& context) { ptr_to_local(&context)->Enter(); }

void v8__Context__Exit(const v8::Context& context) { ptr_to_local(&context)->Exit(); }

v8::Isolate* v8__Context__GetIsolate(const v8::Context& self) {
	return ptr_to_local(&self)->GetIsolate();
}

const v8::Object* v8__Context__Global(
        const v8::Context& self) {
    return local_to_ptr(ptr_to_local(&self)->Global());
}

// ScriptOrigin

void v8__ScriptOrigin__CONSTRUCT(
        v8::ScriptOrigin* buf,
        v8::Isolate* isolate,
        const v8::Value& resource_name) {
    new (buf) v8::ScriptOrigin(isolate, ptr_to_local(&resource_name));
}

// Script

v8::Script* v8__Script__Compile(
        const v8::Context& context,
        const v8::String& src,
        const v8::ScriptOrigin& origin) {
    return maybe_local_to_ptr(
        v8::Script::Compile(ptr_to_local(&context), ptr_to_local(&src), const_cast<v8::ScriptOrigin*>(&origin))
    );
}

v8::Value* v8__Script__Run(
        const v8::Script& script,
        const v8::Context& context) {
    return maybe_local_to_ptr(ptr_to_local(&script)->Run(ptr_to_local(&context)));
}

// String

v8::String* v8__String__NewFromUtf8(
        v8::Isolate* isolate,
        const char* data,
        v8::NewStringType type,
        int length) {
    return maybe_local_to_ptr(
        v8::String::NewFromUtf8(isolate, data, type, length)
    );
}

int v8__String__WriteUtf8(
        const v8::String& str,
        v8::Isolate* isolate,
        char* buffer,
        int length,
        int* nchars_ref,
        int options) {
    return str.WriteUtf8(isolate, buffer, length, nchars_ref, options);
}

int v8__String__Utf8Length(const v8::String& self, v8::Isolate* isolate) {
    return self.Utf8Length(isolate);
}

// Boolean

const v8::Boolean* v8__Boolean__New(
        v8::Isolate* isolate,
        bool value) {
    return local_to_ptr(v8::Boolean::New(isolate, value));
}

// Number

const v8::Number* v8__Number__New(
        v8::Isolate* isolate,
        double value) {
    return *v8::Number::New(isolate, value);
}

// Integer

const v8::Integer* v8__Integer__New(
        v8::Isolate* isolate,
        int32_t value) {
    return *v8::Integer::New(isolate, value);
}

const v8::Integer* v8__Integer__NewFromUnsigned(
        v8::Isolate* isolate,
        uint32_t value) {
    return *v8::Integer::NewFromUnsigned(isolate, value);
}

// Promise

const v8::Promise::Resolver* v8__Promise__Resolver__New(
        const v8::Context& ctx) {
    return maybe_local_to_ptr(
        v8::Promise::Resolver::New(ptr_to_local(&ctx))
    );
}

const v8::Promise* v8__Promise__Resolver__GetPromise(
        const v8::Promise::Resolver& self) {
    return local_to_ptr(ptr_to_local(&self)->GetPromise());
}

void v8__Promise__Resolver__Resolve(
        const v8::Promise::Resolver& self,
        const v8::Context& ctx,
        const v8::Value& value,
        v8::Maybe<bool>* out) {
    *out = ptr_to_local(&self)->Resolve(
        ptr_to_local(&ctx), ptr_to_local(&value)
    );
}

void v8__Promise__Resolver__Reject(
        const v8::Promise::Resolver& self,
        const v8::Context& ctx,
        const v8::Value& value,
        v8::Maybe<bool>* out) {
    *out = ptr_to_local(&self)->Reject(
        ptr_to_local(&ctx),
        ptr_to_local(&value)
    );
}

// Value

const v8::String* v8__Value__ToString(
        const v8::Value& val, const v8::Context& ctx) {
    return maybe_local_to_ptr(val.ToString(ptr_to_local(&ctx)));
}

bool v8__Value__BooleanValue(
        const v8::Value& self,
        v8::Isolate* isolate) {
    return self.BooleanValue(isolate);
}

void v8__Value__Uint32Value(
        const v8::Value& self,
        const v8::Context& ctx,
        v8::Maybe<uint32_t>* out) {
    *out = self.Uint32Value(ptr_to_local(&ctx));
}

void v8__Value__NumberValue(
        const v8::Value& self,
        const v8::Context& ctx,
        v8::Maybe<double>* out) {
    *out = self.NumberValue(ptr_to_local(&ctx));
}

bool v8__Value__IsFunction(const v8::Value& self) { return self.IsFunction(); }

bool v8__Value__IsObject(const v8::Value& self) { return self.IsObject(); }

bool v8__Value__IsArray(const v8::Value& self) { return self.IsArray(); }

void v8__Value__InstanceOf(
        const v8::Value& self,
        const v8::Context& ctx,
        const v8::Object& object,
        v8::Maybe<bool>* out) {
    *out = ptr_to_local(&self)->InstanceOf(ptr_to_local(&ctx), ptr_to_local(&object));
}

// Template

void v8__Template__Set(
        const v8::Template& self,
        const v8::Name& key,
        const v8::Data& value,
        v8::PropertyAttribute attr) {
    ptr_to_local(&self)->Set(ptr_to_local(&key), ptr_to_local(&value), attr);
}

void v8__Template__SetAccessorProperty__DEFAULT(
        const v8::Template& self,
        const v8::Name& key,
        const v8::FunctionTemplate& getter) {
    ptr_to_local(&self)->SetAccessorProperty(ptr_to_local(&key), ptr_to_local(&getter));
}

// ObjectTemplate

const v8::ObjectTemplate* v8__ObjectTemplate__New__DEFAULT(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::ObjectTemplate::New(isolate));
}

const v8::ObjectTemplate* v8__ObjectTemplate__New(
        v8::Isolate* isolate, const v8::FunctionTemplate& constructor) {
    return local_to_ptr(v8::ObjectTemplate::New(isolate, ptr_to_local(&constructor)));
}

const v8::Object* v8__ObjectTemplate__NewInstance(
        const v8::ObjectTemplate& self, const v8::Context& ctx) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->NewInstance(ptr_to_local(&ctx))
    );
}

void v8__ObjectTemplate__SetInternalFieldCount(
        const v8::ObjectTemplate& self,
        int value) {
    ptr_to_local(&self)->SetInternalFieldCount(value);
}

void v8__ObjectTemplate__SetAccessor__DEFAULT(
        const v8::ObjectTemplate& self,
        const v8::Name& key,
        v8::AccessorNameGetterCallback getter) {
    ptr_to_local(&self)->SetAccessor(ptr_to_local(&key), getter);
}

void v8__ObjectTemplate__SetAccessor__DEFAULT2(
        const v8::ObjectTemplate& self,
        const v8::Name& key,
        v8::AccessorNameGetterCallback getter,
        v8::AccessorNameSetterCallback setter) {
    ptr_to_local(&self)->SetAccessor(ptr_to_local(&key), getter, setter);
}

// Array

uint32_t v8__Array__Length(const v8::Array& self) { return self.Length(); }

// Object

const v8::Object* v8__Object__New(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::Object::New(isolate));
}

void v8__Object__SetInternalField(
        const v8::Object& self,
        int index,
        const v8::Value& value) {
    ptr_to_local(&self)->SetInternalField(index, ptr_to_local(&value));
}

const v8::Value* v8__Object__GetInternalField(
        const v8::Object& self,
        int index) {
    return local_to_ptr(ptr_to_local(&self)->GetInternalField(index));
}

const v8::Value* v8__Object__Get(
        const v8::Object& self,
        const v8::Context& ctx,
        const v8::Value& key) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->Get(ptr_to_local(&ctx), ptr_to_local(&key))
    );
}

const v8::Value* v8__Object__GetIndex(
        const v8::Object& self,
        const v8::Context& ctx,
        uint32_t idx) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->Get(ptr_to_local(&ctx), idx)
    );
}

void v8__Object__Set(
        const v8::Object& self,
        const v8::Context& ctx,
        const v8::Value& key,
        const v8::Value& value,
        v8::Maybe<bool>* out) {
    *out = ptr_to_local(&self)->Set(
        ptr_to_local(&ctx),
        ptr_to_local(&key),
        ptr_to_local(&value)
    );
}

void v8__Object__DefineOwnProperty(
        const v8::Object& self,
        const v8::Context& ctx,
        const v8::Name& key,
        const v8::Value& value,
        v8::PropertyAttribute attr,
        v8::Maybe<bool>* out) {
    *out = ptr_to_local(&self)->DefineOwnProperty(
        ptr_to_local(&ctx),
        ptr_to_local(&key),
        ptr_to_local(&value),
        attr
    );
}

// FunctionCallbackInfo

v8::Isolate* v8__FunctionCallbackInfo__GetIsolate(
        const v8::FunctionCallbackInfo<v8::Value>& self) {
    return self.GetIsolate();
}

int v8__FunctionCallbackInfo__Length(
        const v8::FunctionCallbackInfo<v8::Value>& self) {
    return self.Length();
}

const v8::Value* v8__FunctionCallbackInfo__INDEX(
        const v8::FunctionCallbackInfo<v8::Value>& self, int i) {
    return local_to_ptr(self[i]);
}

void v8__FunctionCallbackInfo__GetReturnValue(
        const v8::FunctionCallbackInfo<v8::Value>& self,
        v8::ReturnValue<v8::Value>* out) {
    // Can't return incomplete type to C so copy to res pointer.
    *out = self.GetReturnValue();
}

const v8::Object* v8__FunctionCallbackInfo__This(
        const v8::FunctionCallbackInfo<v8::Value>& self) {
    return local_to_ptr(self.This());
}

// PropertyCallbackInfo

v8::Isolate* v8__PropertyCallbackInfo__GetIsolate(
        const v8::PropertyCallbackInfo<v8::Value>& self) {
    return self.GetIsolate();
}

void v8__PropertyCallbackInfo__GetReturnValue(
        const v8::PropertyCallbackInfo<v8::Value>& self,
        v8::ReturnValue<v8::Value>* out) {
    *out = self.GetReturnValue();
}

const v8::Object* v8__PropertyCallbackInfo__This(
        const v8::PropertyCallbackInfo<v8::Value>& self) {
    return local_to_ptr(self.This());
}

// ReturnValue

void v8__ReturnValue__Set(
        v8::ReturnValue<v8::Value> self,
        const v8::Value& value) {
    self.Set(ptr_to_local(&value));
}

const v8::Value* v8__ReturnValue__Get(
        v8::ReturnValue<v8::Value> self) {
    return local_to_ptr(self.Get());
}

// FunctionTemplate

const v8::FunctionTemplate* v8__FunctionTemplate__New__DEFAULT(
        v8::Isolate* isolate) {
    return local_to_ptr(v8::FunctionTemplate::New(isolate));
}

const v8::FunctionTemplate* v8__FunctionTemplate__New__DEFAULT2(
        v8::Isolate* isolate,
        v8::FunctionCallback callback_or_null) {
    return local_to_ptr(v8::FunctionTemplate::New(isolate, callback_or_null));
}

const v8::ObjectTemplate* v8__FunctionTemplate__InstanceTemplate(
        const v8::FunctionTemplate& self) {
    return local_to_ptr(ptr_to_local(&self)->InstanceTemplate());
}

const v8::ObjectTemplate* v8__FunctionTemplate__PrototypeTemplate(
        const v8::FunctionTemplate& self) {
    return local_to_ptr(ptr_to_local(&self)->PrototypeTemplate());
}

const v8::Function* v8__FunctionTemplate__GetFunction(
        const v8::FunctionTemplate& self, const v8::Context& context) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->GetFunction(ptr_to_local(&context))
    );
}

void v8__FunctionTemplate__SetClassName(
        const v8::FunctionTemplate& self,
        const v8::String& name) {
    ptr_to_local(&self)->SetClassName(ptr_to_local(&name));
}

void v8__FunctionTemplate__ReadOnlyPrototype(
        const v8::FunctionTemplate& self) {
    ptr_to_local(&self)->ReadOnlyPrototype();
}

// Function

const v8::Value* v8__Function__Call(
        const v8::Function& self,
        const v8::Context& context,
        const v8::Value& recv,
        int argc,
        const v8::Value* const argv[]) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->Call(
            ptr_to_local(&context),
            ptr_to_local(&recv),
            argc, const_ptr_array_to_local_array(argv)
        )
    );
}

const v8::Object* v8__Function__NewInstance(
        const v8::Function& self,
        const v8::Context& context,
        int argc,
        const v8::Value* const argv[]) {
    return maybe_local_to_ptr(
        ptr_to_local(&self)->NewInstance(
            ptr_to_local(&context),
            argc,
            const_ptr_array_to_local_array(argv)
        )
    );
}

// Persistent

void v8__Persistent__New(
        v8::Isolate* isolate,
        const v8::Value& value,
        v8::Persistent<v8::Value>* out) {
    new (out) v8::Persistent<v8::Value>(isolate, ptr_to_local(&value));
}

void v8__Persistent__Reset(
        v8::Persistent<v8::Value>* self) {
    // v8::Persistent by default uses NonCopyablePersistentTraits which will create a bad copy if we accept v8::Persistent<v8::Value> as the arg.
    // Instead we operate on its pointer.
    self->Reset();
}

void v8__Persistent__SetWeak(
        v8::Persistent<v8::Value>* self) {
    self->SetWeak();
}

void v8__Persistent__SetWeakFinalizer(
        v8::Persistent<v8::Value>* self,
        void* finalizer_ctx,
        v8::WeakCallbackInfo<void>::Callback finalizer_cb,
        v8::WeakCallbackType type) {
    self->SetWeak(finalizer_ctx, finalizer_cb, type);
}

// WeakCallbackInfo

v8::Isolate* v8__WeakCallbackInfo__GetIsolate(
        const v8::WeakCallbackInfo<void>& self) {
    return self.GetIsolate();
}

void* v8__WeakCallbackInfo__GetParameter(
        const v8::WeakCallbackInfo<void>& self) {
    return self.GetParameter();
}

// Exception

const v8::Value* v8__Exception__Error(
        const v8::String& message) {
    return local_to_ptr(v8::Exception::Error(ptr_to_local(&message)));
}

// TryCatch

size_t v8__TryCatch__SIZEOF() {
    return sizeof(v8::TryCatch);
}

void v8__TryCatch__CONSTRUCT(
        v8::TryCatch* buf, v8::Isolate* isolate) {
    construct_in_place<v8::TryCatch>(buf, isolate);
}

void v8__TryCatch__DESTRUCT(v8::TryCatch* self) { self->~TryCatch(); }

const v8::Value* v8__TryCatch__Exception(const v8::TryCatch& self) {
    return local_to_ptr(self.Exception());
}

const v8::Message* v8__TryCatch__Message(const v8::TryCatch& self) {
    return local_to_ptr(self.Message());
}

bool v8__TryCatch__HasCaught(const v8::TryCatch& self) {
    return self.HasCaught();
}

const v8::Value* v8__TryCatch__StackTrace(
        const v8::TryCatch& self,
        const v8::Context& context) {
    return maybe_local_to_ptr(self.StackTrace(ptr_to_local(&context)));
}

// Message

const v8::String* v8__Message__GetSourceLine(
        const v8::Message& self,
        const v8::Context& context) {
    return maybe_local_to_ptr(self.GetSourceLine(ptr_to_local(&context)));
}

const v8::Value* v8__Message__GetScriptResourceName(const v8::Message& self) {
    return local_to_ptr(self.GetScriptResourceName());
}

int v8__Message__GetLineNumber(
        const v8::Message& self,
        const v8::Context& context) {
    v8::Maybe<int> maybe = self.GetLineNumber(ptr_to_local(&context));
    return maybe.FromMaybe(-1);
}

int v8__Message__GetStartColumn(const v8::Message& self) {
    return self.GetStartColumn();
}

int v8__Message__GetEndColumn(const v8::Message& self) {
    return self.GetEndColumn();
}

}