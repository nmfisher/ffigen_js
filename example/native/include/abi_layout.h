#ifndef EXAMPLE_ABI_LAYOUT_H
#define EXAMPLE_ABI_LAYOUT_H

// Keep the fixture self-contained for parser tests without a C sysroot.
// These aliases match <stdint.h> on the Wasm32 target used by the example.
typedef unsigned char uint8_t;
typedef short int16_t;

#ifdef __cplusplus
extern "C" {
#endif

typedef struct Padded {
    uint8_t enabled;
    float values[3];
    uint8_t tail;
} Padded;
typedef struct Nested {
    uint8_t tag;
    Padded entry;
    uint8_t end;
} Nested;
typedef struct __attribute__((packed)) Packed {
    uint8_t tag;
    float amount;
    int16_t count;
    Padded entry;
    float samples[2];
} Packed;
typedef union Choice {
    uint8_t byte;
    double number;
    Padded record;
} Choice;
typedef struct Anonymous {
    uint8_t tag;
    union {
        int code;
        struct { uint8_t flag; float amount; };
    };
    uint8_t tail;
} Anonymous;
typedef struct __attribute__((aligned(16))) OverAligned {
    uint8_t tail;
} OverAligned;
typedef struct Arrays {
    uint8_t tag;
    Padded entries[2];
    float matrix[2][3];
    uint8_t tail;
} Arrays;
typedef struct Bitfield { unsigned int flag: 1; float value; } Bitfield;

void usePadded(Padded *value);
void useNested(Nested *value);
void usePacked(Packed *value);
void useChoice(Choice *value);
void useAnonymous(Anonymous *value);
void useOverAligned(OverAligned *value);
void useArrays(Arrays *value);
void useBitfield(Bitfield *value);
int checkPadded(Padded *value);
int checkPacked(Packed *value);
void fillNested(Nested *value);
void fillPacked(Packed *value);
void fillChoice(Choice *value);
int checkSizes(int padded, int nested, int packed, int choice);
#ifdef __cplusplus
}
#endif
#endif
