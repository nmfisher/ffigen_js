// Dual-target smoke fixture: this ONE header/source is compiled to a native
// shared library (dart:ffi side) AND to an Emscripten module (dart:js_interop
// side). Function names are camelCase so ffigen (native) and jsgen (web)
// emit identical Dart names with no rename config.
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  float x;
  float y;
} DualPoint;

int dualAdd(int a, int b);

// Scales *p in place by k.
void dualPointScale(DualPoint *p, float k);

// Writes "hello, <name>!" into out (at most outLen bytes, NUL-terminated)
// and returns the number of bytes written (excluding the NUL).
int dualGreet(const char *name, char *out, int outLen);

#ifdef __cplusplus
}
#endif
