#include <moonbit.h>
#include <stdint.h>

typedef struct moonbit_co_context {
  uint64_t rsp;
  uint64_t rbp;
  uint64_t rbx;
  uint64_t r12;
  uint64_t r13;
  uint64_t r14;
  uint64_t r15;
  uint64_t rax;
} moonbit_co_context_t;

MOONBIT_FFI_EXPORT
moonbit_co_context_t *
moonbit_co_context_make(void) {
  return (moonbit_co_context_t *)moonbit_make_bytes(
    sizeof(moonbit_co_context_t), 0
  );
}

MOONBIT_FFI_EXPORT
void *
moonbit_co_stack_make(uint64_t size) {
  return (void *)moonbit_make_bytes((int32_t)size, 0);
}

extern void
moonbit_co_shift(moonbit_co_context_t *from, moonbit_co_context_t *to);

extern void
moonbit_co__reset(
  moonbit_co_context_t *context,
  void *stack_top,
  void (*func)(void *),
  void *data
);

MOONBIT_FFI_EXPORT
void
moonbit_co_reset(
  moonbit_co_context_t *context,
  void *stack_base,
  uint64_t stack_size,
  void (*func)(void *),
  void *data
) {
  uintptr_t sp = (uintptr_t)stack_base + stack_size;
  sp &= ~(uintptr_t)0xF;
  moonbit_co__reset(context, (void *)sp, func, data);
}
