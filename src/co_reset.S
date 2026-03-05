// moonbit_co__reset(ctx, stack_top, func, arg)
//
// Saves the current context into ctx, switches sp to stack_top,
// calls func(arg) on the new stack. When func returns, restores
// the saved context from ctx and returns to the caller.

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
.globl SYMBOL(moonbit_co__reset)
FUNC_TYPE(SYMBOL(moonbit_co__reset))
.p2align 2
SYMBOL(moonbit_co__reset):

#if defined(__x86_64__)
  // x86_64: rdi=ctx, rsi=stack_top, rdx=func, rcx=arg

  // Save callee-saved registers into ctx
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

  // Preserve ctx pointer in a callee-saved register
  movq %rdi, %r12

  // Switch to the new stack
  movq %rsi, %rsp

  // Call func(arg)
  movq %rcx, %rdi
  callq *%rdx

  // Restore context from ctx
  movq 0(%r12), %rsp
  movq 8(%r12), %rbp
  movq 16(%r12), %rbx
  movq 32(%r12), %r13
  movq 40(%r12), %r14
  movq 48(%r12), %r15
  movq 56(%r12), %rax
  movq %rax, (%rsp)
  movq 24(%r12), %r12

  ret

#elif defined(__aarch64__)
  // arm64: x0=ctx, x1=stack_top, x2=func, x3=arg

  // Save callee-saved registers into ctx
  mov x9, sp
  str x9, [x0, #0]        // sp
  stp x29, x30, [x0, #8]  // fp, lr
  stp x19, x20, [x0, #24]
  stp x21, x22, [x0, #40]
  stp x23, x24, [x0, #56]
  stp x25, x26, [x0, #72]
  stp x27, x28, [x0, #88]

  // Preserve ctx pointer in a callee-saved register
  mov x19, x0

  // Switch to the new stack
  mov sp, x1

  // Call func(arg)
  mov x0, x3
  blr x2

  // Restore context from ctx (x19 may have been overwritten by shift)
  ldr x9, [x19, #0]
  mov sp, x9
  ldp x29, x30, [x19, #8]
  ldp x21, x22, [x19, #40]
  ldp x23, x24, [x19, #56]
  ldp x25, x26, [x19, #72]
  ldp x27, x28, [x19, #88]
  // x19, x20 last since we're using x19 as ctx pointer
  ldr x20, [x19, #32]
  ldr x19, [x19, #24]

  ret

#else
#error "Unsupported architecture"
#endif

FUNC_SIZE(SYMBOL(moonbit_co__reset))
