#include "../../test/fixtures/layout.h"
#include <stddef.h>

_Static_assert(sizeof(Padded) == 20, "Padded size");
_Static_assert(offsetof(Padded, values) == 4, "Padded.values offset");
_Static_assert(sizeof(Packed) == 35, "Packed size");
_Static_assert(offsetof(Packed, entry) == 7, "Packed.entry offset");
_Static_assert(sizeof(Choice) == 24, "Choice size");

int checkPadded(Padded *v) {
    return v->enabled == 7 && v->values[0] == 0.125f &&
        v->values[1] == 0.5f && v->values[2] == 0.875f && v->tail == 9;
}
int checkPacked(Packed *v) {
    Padded entry = v->entry;
    return v->tag == 5 && v->amount == 1.25f && v->count == -1234 &&
        checkPadded(&entry) && v->samples[0] == 2.0f && v->samples[1] == 4.0f;
}
void fillNested(Nested *v) {
    v->tag = 3;
    v->entry = (Padded){7, {0.125f, 0.5f, 0.875f}, 9};
    v->end = 11;
}
void fillPacked(Packed *v) {
    v->tag = 5;
    v->amount = 1.25f;
    v->count = -1234;
    v->entry = (Padded){7, {0.125f, 0.5f, 0.875f}, 9};
    v->samples[0] = 2.0f;
    v->samples[1] = 4.0f;
}
void fillChoice(Choice *v) { v->number = 8.5; }
int checkSizes(int padded, int nested, int packed, int choice) {
    return padded == sizeof(Padded) && nested == sizeof(Nested) &&
        packed == sizeof(Packed) && choice == sizeof(Choice);
}
