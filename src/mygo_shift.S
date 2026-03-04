// mygo_shift(mygo_context_t *from, mygo_context_t *to)
//   rdi = from   (context struct to save current state into)
//   rsi = to     (context struct to load new state from)
//
// Saves the current context (callee-saved registers + return address)
// into `from`, then loads the context from `to` and returns into it.
//
// This is the primitive for both yielding (shift) and resuming:
//   - To shift (yield to delimiter): mygo_shift(&continuation, &reset_ctx)
//   - To resume a continuation:      mygo_shift(&reset_ctx, &continuation)

.text
.globl mygo_shift
.type mygo_shift, @function
mygo_shift:
  // Save callee-saved registers into from
  movq %rsp, 0(%rdi)
  movq %rbp, 8(%rdi)
  movq %rbx, 16(%rdi)
  movq %r12, 24(%rdi)
  movq %r13, 32(%rdi)
  movq %r14, 40(%rdi)
  movq %r15, 48(%rdi)
  // Save return address (sitting at top of stack) into from
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
  // Load return address from to and place on top of stack
  movq 56(%rsi), %rax
  movq %rax, (%rsp)

  ret
.size mygo_shift, .-mygo_shift
