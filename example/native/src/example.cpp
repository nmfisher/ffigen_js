#include <emscripten.h>
#include <emscripten/stack.h>
#include <emscripten/console.h>
#include <emscripten/val.h>
#include <emscripten/bind.h>

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "example.h"

extern "C" {
EMSCRIPTEN_KEEPALIVE uint64_t GLOBALINT = 9223372036854775808;

void EMSCRIPTEN_KEEPALIVE write(int32_t *out) {
    
    *out = 10;
}

void EMSCRIPTEN_KEEPALIVE check_buffer(uint8_t *addr) {
    for(int i = 0; i < 10; i++) {
        emscripten_console_logf("%d %d", i, addr[i]);
    }
}

emscripten::val emscripten_make_buffer(int ptr, int length) {
    // char* buffer =(char*)malloc(length);
    char *buffer = (char*)ptr;
    for(int i = 0; i < length; i++) {
        buffer[i] = i;
    }

    check_buffer((uint8_t*)ptr);
    auto v = emscripten::val(emscripten::typed_memory_view(length, buffer));
    return v;
}

EMSCRIPTEN_BINDINGS(module) {
    emscripten::function("_emscripten_make_buffer", &emscripten_make_buffer, emscripten::allow_raw_pointers());
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
    return emscripten_stack_get_free();
}

EMSCRIPTEN_KEEPALIVE bool returns_bool() {
    return false;
}

}
