// moonbit_co__reset(moonbit_co_context_t *ctx, void *stack_top, void (*func)(void *), void *arg)
//   rdi = ctx        (context struct to save caller's state into)
//   rsi = stack_top   (top of the new stack, must be 16-byte aligned)
//   rdx = func        (function pointer to call)
//   rcx = arg         (argument to pass to func)
//
// Saves the current context into ctx, switches rsp to stack_top,
// calls func(arg) on the new stack. When func returns, restores
// the saved context from ctx and returns to the caller.
//
// If func calls moonbit_co_shift to save its context and load ctx,
// moonbit_co__reset effectively "returns early". A later moonbit_co_shift that
// overwrites ctx and loads the saved continuation will cause func
// to resume; when func eventually returns, the epilogue restores
// ctx (now pointing to the resumer) and returns to the resumer.

.text
.globl moonbit_co__reset
.type moonbit_co__reset, @function
moonbit_co__reset:
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

  // Preserve ctx pointer in a callee-saved register so we can
  // access it after func returns.
  movq %rdi, %r12

  // Switch to the new stack (caller must ensure stack_top is 16-byte aligned)
  movq %rsi, %rsp

  // Call func(arg): move arg to rdi (first parameter), func is in rdx
  movq %rcx, %rdi
  callq *%rdx

  // func returned normally — restore context from ctx (which may have
  // been overwritten by a moonbit_co_shift resume, pointing to the resumer).
  movq 0(%r12), %rsp
  movq 8(%r12), %rbp
  movq 16(%r12), %rbx
  // r12 is restored last since we're using it as the ctx pointer
  movq 32(%r12), %r13
  movq 40(%r12), %r14
  movq 48(%r12), %r15
  movq 56(%r12), %rax
  movq %rax, (%rsp)
  movq 24(%r12), %r12

  ret
.size moonbit_co__reset, .-moonbit_co__reset
