#include <stdio.h>
#include <string.h>
#include "dual.h"

int dualAdd(int a, int b) { return a + b; }

void dualPointScale(DualPoint *p, float k) {
  p->x *= k;
  p->y *= k;
}

int dualGreet(const char *name, char *out, int outLen) {
  return snprintf(out, outLen, "hello, %s!", name);
}
