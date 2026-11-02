#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/stack.h>
#include <emscripten/console.h>
#include <emscripten/val.h>
#include <emscripten/bind.h>
#endif

#ifndef EMSCRIPTEN_KEEPALIVE
#define EMSCRIPTEN_KEEPALIVE __attribute__((visibility("default")))
#define emscripten_console_logf printf
#endif

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "example.h"

extern "C" {
EMSCRIPTEN_KEEPALIVE uint64_t GLOBALINT = 9223372036854775808;

void EMSCRIPTEN_KEEPALIVE write(int32_t *out) {
    
    *out = 10;
}

void EMSCRIPTEN_KEEPALIVE write_uint8_for_address_test(uint8_t *out) {
    out[0] = 201;
}

void EMSCRIPTEN_KEEPALIVE write_int16_for_address_test(int16_t *out) {
    out[0] = -1234;
}

void EMSCRIPTEN_KEEPALIVE write_uint16_for_address_test(uint16_t *out) {
    out[0] = 54321;
}

void EMSCRIPTEN_KEEPALIVE write_int32_for_address_test(int32_t *out) {
    out[0] = -123456789;
}

void EMSCRIPTEN_KEEPALIVE write_int64_for_address_test(int64_t *out) {
    out[0] = -9007199254740995LL;
}

void EMSCRIPTEN_KEEPALIVE write_uint32_for_address_test(uint32_t *out) {
    out[0] = 3456789012u;
}

void EMSCRIPTEN_KEEPALIVE write_float32_for_address_test(float *out) {
    out[0] = 12.5f;
}

void EMSCRIPTEN_KEEPALIVE write_float64_for_address_test(double *out) {
    out[0] = 9876.5;
}

bool EMSCRIPTEN_KEEPALIVE verify_typed_data_inputs_for_address_test(
        uint8_t *uint8_value,
        int16_t *int16_value,
        uint16_t *uint16_value,
        int32_t *int32_value,
        int64_t *int64_value,
        uint32_t *uint32_value,
        float *float32_value,
        double *float64_value) {
    return uint8_value[0] == 17 &&
        int16_value[0] == -18 &&
        uint16_value[0] == 60000 &&
        int32_value[0] == -1234567 &&
        int64_value[0] == -9007199254740993LL &&
        uint32_value[0] == 4000000000u &&
        float32_value[0] == 1.25f &&
        float64_value[0] == -2.5;
}

void EMSCRIPTEN_KEEPALIVE check_buffer(uint8_t *addr) {
    for(int i = 0; i < 10; i++) {
        emscripten_console_logf("%d %d", i, addr[i]);
    }
}

/** Adds 2 integers. */
int EMSCRIPTEN_KEEPALIVE sum(int a, int b) {
    return a + b;
}

INTTYPE EMSCRIPTEN_KEEPALIVE sum_with_typedef(INTTYPE a, INTTYPE b) {
    return a + b;
}

int EMSCRIPTEN_KEEPALIVE subtract(int *a, int b) {
    return *a - b;
}

int *EMSCRIPTEN_KEEPALIVE multiply(int a, int b) {
    int *result = (int *)malloc(sizeof(int));
    *result = a * b;
    return result;
}

float *EMSCRIPTEN_KEEPALIVE divide(int a, int b) {
    float *result = (float *)malloc(sizeof(float));
    *result = (float)a / b;
    return result;
}

double EMSCRIPTEN_KEEPALIVE *  return_array() {
    double *arr = (double*)malloc(sizeof(double) * 4);
    arr[0] = 1.0;
    arr[1] = 2.0;
    arr[2] = 3.0;
    arr[3] = 4.0;
    return arr;
}

int ** EMSCRIPTEN_KEEPALIVE ptr_ptr(int **a, int **b) {
    int **out = (int **)malloc(sizeof(int*) * 2);
    out[0] = (int *)malloc(sizeof(int*));
    out[1] = (int *)malloc(sizeof(int*));
    *out[0] = **b;
    *out[1] = **a;
    return out;
}

double *EMSCRIPTEN_KEEPALIVE divide_precision(float *a, float *b) {
    double *result = (double *)malloc(sizeof(double));
    *result = (double)*a / (double)*b;
    return result;
}

const char *EMSCRIPTEN_KEEPALIVE copy_string(const char *instr) {
    char * outstr = (char*)malloc(strlen(instr) + 1);
    strcpy(outstr, instr);
    return outstr;
}

MyStruct EMSCRIPTEN_KEEPALIVE return_struct_by_value(float a, const char *b) {
    MyStruct result;
    result.a = a;
    result.c = 2;
    char *str_copy = (char *)malloc(strlen(b) + 1);
    emscripten_console_logf("str copy : %d", str_copy);
    strcpy(str_copy, b);
    result.b = str_copy;
    return result;
}

StructWithArray EMSCRIPTEN_KEEPALIVE return_struct_with_array_by_value() {
    StructWithArray result;
    result.array1[0] = 10.0;
    result.array1[1] = 20.0;
    result.array2[0] = 30.0;
    result.array2[1] = 40.0;
    result.array2[2] = 50.0;
    return result;
}

int EMSCRIPTEN_KEEPALIVE struct_as_argument(double3 vector) {
    return (int)(vector.x + vector.y + vector.z);
}

EMSCRIPTEN_KEEPALIVE void accept_struct_ptr(MyStruct *arg) {
    emscripten_console_logf("OK");
}

void EMSCRIPTEN_KEEPALIVE accept_fn_pointer_with_no_args(void(*callback)()) {
    void* foo = (void*)100;
    callback();
}

void EMSCRIPTEN_KEEPALIVE accept_fn_typedef_arg(FunctionTypedef arg) {
    arg(NULL);
}

void EMSCRIPTEN_KEEPALIVE accept_fn_pointer_with_primitive_args(void(*callback)(int arg)) {
    if (callback != NULL) {
        callback(42);
    }
}

void EMSCRIPTEN_KEEPALIVE accept_fn_pointer_with_ptr_args(void(*callback)(MyStruct *arg)) {
    callback(NULL);
}

MyEnum EMSCRIPTEN_KEEPALIVE returnEnum() {
    return ENUM_VAL1;
}

int EMSCRIPTEN_KEEPALIVE acceptEnum(MyEnum val) {
    switch(val) {
        case ENUM_VAL1:
            return 0;
        case ENUM_VAL2:
            return 1;
    }
}

EMSCRIPTEN_KEEPALIVE uint64_t bigint_method(uint64_t number) {
    emscripten_console_logf("Number is %l", number);
    return number + 1;
}

EMSCRIPTEN_KEEPALIVE size_t size_tmethod(size_t number) {
    emscripten_console_logf("size_t number is %d", number);
    return number + 1;
}

EMSCRIPTEN_KEEPALIVE size_t get_stack_free() {
    #ifdef __EMSCRIPTEN__
    return emscripten_stack_get_free();
    #else
    return 0;
    #endif
}

EMSCRIPTEN_KEEPALIVE bool returns_bool() {
    return false;
}

void EMSCRIPTEN_KEEPALIVE foo(TGltfMeshData str) {
    emscripten_console_logf("foo called: vertexCount=%d, indexCount=%d, primitiveType=%d",
        str.vertexCount, str.indexCount, str.primitiveType);
}

// ABI layout regression checks shared by both Dart consumers.
static_assert(sizeof(Padded) == 20, "Padded size");
static_assert(offsetof(Padded, values) == 4, "Padded.values offset");
static_assert(sizeof(Packed) == 35, "Packed size");
static_assert(offsetof(Packed, entry) == 7, "Packed.entry offset");
static_assert(sizeof(Choice) == 24, "Choice size");

int EMSCRIPTEN_KEEPALIVE checkPadded(Padded *v) {
    return v->enabled == 7 && v->values[0] == 0.125f &&
        v->values[1] == 0.5f && v->values[2] == 0.875f && v->tail == 9;
}
int EMSCRIPTEN_KEEPALIVE checkPacked(Packed *v) {
    Padded entry = v->entry;
    return v->tag == 5 && v->amount == 1.25f && v->count == -1234 &&
        checkPadded(&entry) && v->samples[0] == 2.0f && v->samples[1] == 4.0f;
}
void EMSCRIPTEN_KEEPALIVE fillNested(Nested *v) {
    v->tag = 3;
    v->entry = Padded{7, {0.125f, 0.5f, 0.875f}, 9};
    v->end = 11;
}
void EMSCRIPTEN_KEEPALIVE fillPacked(Packed *v) {
    v->tag = 5;
    v->amount = 1.25f;
    v->count = -1234;
    v->entry = Padded{7, {0.125f, 0.5f, 0.875f}, 9};
    v->samples[0] = 2.0f;
    v->samples[1] = 4.0f;
}
void EMSCRIPTEN_KEEPALIVE fillChoice(Choice *v) { v->number = 8.5; }
int EMSCRIPTEN_KEEPALIVE checkSizes(int padded, int nested, int packed, int choice) {
    return padded == sizeof(Padded) && nested == sizeof(Nested) &&
        packed == sizeof(Packed) && choice == sizeof(Choice);
}

}
