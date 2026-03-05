// moonbit_co_shift(from, to)
//
// Saves the current context into `from`, then loads the context
// from `to` and returns into it.

#if defined(__APPLE__)
#define SYMBOL(name) _##name
#define FUNC_TYPE(name)
#define FUNC_SIZE(name)
#else
#define SYMBOL(name) name
#define FUNC_TYPE(name) .type name, @function
#define FUNC_SIZE(name) .size name, .-name
#endif

.text
.globl SYMBOL(moonbit_co_shift)
FUNC_TYPE(SYMBOL(moonbit_co_shift))
.p2align 2
SYMBOL(moonbit_co_shift):

#if defined(__x86_64__)
  // x86_64: rdi=from, rsi=to

  // Save callee-saved registers into from
  movq %rsp, 0(%rdi)
  movq %rbp, 8(%rdi)
  movq %rbx, 16(%rdi)
  movq %r12, 24(%rdi)
  movq %r13, 32(%rdi)
  movq %r14, 40(%rdi)
  movq %r15, 48(%rdi)
  // Save return address
  movq (%rsp), %rax
  movq %rax, 56(%rdi)

  // Load callee-saved registers from to
  movq 0(%rsi), %rsp
  movq 8(%rsi), %rbp
  movq 16(%rsi), %rbx
  movq 24(%rsi), %r12
  movq 32(%rsi), %r13
  movq 40(%rsi), %r14
  movq 48(%rsi), %r15
  // Load return address
  movq 56(%rsi), %rax
  movq %rax, (%rsp)

  ret

#elif defined(__aarch64__)
  // arm64: x0=from, x1=to

  // Save callee-saved registers into from
  mov x9, sp
  str x9, [x0, #0]        // sp
  stp x29, x30, [x0, #8]  // fp, lr
  stp x19, x20, [x0, #24]
  stp x21, x22, [x0, #40]
  stp x23, x24, [x0, #56]
  stp x25, x26, [x0, #72]
  stp x27, x28, [x0, #88]

  // Load callee-saved registers from to
  ldr x9, [x1, #0]
  mov sp, x9
  ldp x29, x30, [x1, #8]
  ldp x19, x20, [x1, #24]
  ldp x21, x22, [x1, #40]
  ldp x23, x24, [x1, #56]
  ldp x25, x26, [x1, #72]
  ldp x27, x28, [x1, #88]

  ret

#else
#error "Unsupported architecture"
#endif

FUNC_SIZE(SYMBOL(moonbit_co_shift))
