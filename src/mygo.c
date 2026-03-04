#include <moonbit.h>
#include <stdint.h>

typedef struct mygo_context {
  uint64_t rsp;
  uint64_t rbp;
  uint64_t rbx;
  uint64_t r12;
  uint64_t r13;
  uint64_t r14;
  uint64_t r15;
  uint64_t rax;
} mygo_context_t;

MOONBIT_FFI_EXPORT
mygo_context_t *
mygo_context_make(void) {
  return (mygo_context_t *)moonbit_make_bytes(sizeof(mygo_context_t), 0);
}

MOONBIT_FFI_EXPORT
void *
mygo_stack_make(uint64_t size) {
  return (void *)moonbit_make_bytes((int32_t)size, 0);
}

extern void
mygo_shift(mygo_context_t *from, mygo_context_t *to);

extern void
mygo__reset(
  mygo_context_t *context,
  void *stack_top,
  void (*func)(void *),
  void *data
);

MOONBIT_FFI_EXPORT
void
mygo_reset(
  mygo_context_t *context,
  void *stack_base,
  uint64_t stack_size,
  void (*func)(void *),
  void *data
) {
  uintptr_t sp = (uintptr_t)stack_base + stack_size;
  sp &= ~(uintptr_t)0xF;
  mygo__reset(context, (void *)sp, func, data);
}
